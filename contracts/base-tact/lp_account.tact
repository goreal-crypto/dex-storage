message AddLiquidity {
    query_id: Int;
    new_amount0: Int;
    new_amount1: Int;
    min_lp_out: Int;
}

message CbAddLiquidity {
    query_id: Int;
    amount0: Int;
    amount1: Int;
    user_address: Address;
    min_lp_out: Int;
}

message RefundMe {
    query_id: Int;
}

message CbRefundMe {
    query_id: Int;
    amount0: Int;
    amount1: Int;
    user_address: Address;
}

message DirectAddLiquidity {
    query_id: Int;
    amount0: Int;
    amount1: Int;
    min_lp_out: Int;
}

const WRONG_OP: Int = 1234;
const ZERO_OUTPUT: Int = 1235;
const NO_LIQUIDITY: Int = 1236; 

contract LPAccount {
    user_address: Address;
    pool_address: Address;
    amount0: Int;
    amount1: Int;

    init(user_address: Address, pool_address: Address, amount0: Int, amount1: Int) {
        self.user_address = user_address;
        self.pool_address = pool_address;
        self.amount0 = amount0;
        self.amount1 = amount1;
    }
    
    receive(){}

    receive(msg: AddLiquidity) {
        throwUnless(WRONG_OP, sender() == self.pool_address);
        self.amount0 += msg.new_amount0;
        self.amount1 += msg.new_amount1;
        if ((msg.min_lp_out > 0) && (self.amount0 > 1000) && (self.amount1 > 1000)){
            message(MessageParameters {
                to: self.pool_address,
                value: 0,
                mode: SendRemainingBalance,
                bounce: false,
                body: CbAddLiquidity {
                    query_id: msg.query_id,
                    amount0: self.amount0,
                    amount1: self.amount1,
                    user_address: self.user_address,
                    min_lp_out: msg.min_lp_out
                }.toCell()
            });
            self.amount0 = 0;
            self.amount1 = 0;
        }   
    }

    receive(msg: RefundMe) {
        throwUnless(WRONG_OP, sender() == self.user_address);
        throwUnless(NO_LIQUIDITY, (self.amount0 > 0) || (self.amount1 > 0));
        message(MessageParameters {
            to: self.pool_address,
            value: 0, 
            mode: SendRemainingValue,
            bounce: false,
            body: CbRefundMe {
                query_id: msg.query_id,
                amount0: self.amount0,
                amount1: self.amount1,
                user_address: self.user_address
            }.toCell()
        });

        self.amount0 = 0;
        self.amount1 = 0;
    }

    receive(msg: DirectAddLiquidity) {
        throwUnless(WRONG_OP, sender() == self.user_address);
        throwUnless(ZERO_OUTPUT, (msg.min_lp_out > 0) && (self.amount0 > 1000) && (self.amount1 > 1000));
        self.amount0 -= msg.amount0;
        self.amount1 -= msg.amount1;
        throwUnless(NO_LIQUIDITY, (self.amount0 >= 0) && (self.amount1 >= 0));
        message(MessageParameters {
            to: self.pool_address,
            value: 0,
            mode: SendRemainingValue,
            bounce: false,
            body: CbAddLiquidity {
                query_id: msg.query_id,
                amount0: msg.amount0,
                amount1: msg.amount1,
                user_address: self.user_address,
                min_lp_out: msg.min_lp_out,
            }.toCell()
        });
    }

    // receive(msg: ResetGas) {}
}