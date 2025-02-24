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

contract LPAccount {
    user_address: Address;
    pool_address: Address;
    amount0: Int;
    amount1: Int;

    receive(msg: AddLiquidity) {
        self.amount0 = self.amount0 + msg.new_amount0;
        self.amount1 = self.amount1 + msg.new_amount1;
        if (msg.min_lp_out && ((self.amount0 > 1000) && (self.amount1 > 1000))){
            send(SendParameters{
                to: self.pool_address,
                value: 0, // TODO
                mode: SendRemainingValue, // TODO
                bounce: false, // TODO
                body: CbAddLiquidity {
                    query_id: msg.query_id,
                    amount0: self.amount0,
                    amount1: self.amount1,
                    user_address: self.user_address,
                    min_lp_out: msg.min_lp_out
                }
            });
            self.amount0 = 0;
            self.amount1 = 0;
        }   
    }

    receive(msg: RefundMe) {
        // TODO
    }

    receive(msg: DirectAddLiquidity) {
        // TODO
    }
}