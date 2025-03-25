import "./lp_account";
import "./messages";
import "./lp_wallet";

inline fun getLPAccountStateInit(userAddress: Address, poolAddress: Address): StateInit {
    return initOf LPAccount(
        userAddress,
        poolAddress,
        0,
        0
    );
}

inline fun getLPAccountAddress(userAddress: Address, poolAddress: Address): Address {
    return contractAddress(getLPAccountStateInit(userAddress, poolAddress));
}

//TODO fees
inline fun getAmountOut(amountIn: Int, reserveIn: Int, reserveOut: Int): Int {
    let baseOut: Int = (amountIn * reserveOut) / (reserveIn + amountIn);
    return baseOut;
}

contract Pool {
    routerAddress: Address;
    // lp_fee: Int;
    // protocol_fee: Int;
    // ref_fee: Int;
    token0Address: Address;
    token1Address: Address;
    totalSupplyLP: Int as coins; 
    // collected_token0_protocol_fee: Int;
    // collected_token1_protocol_fee: Int; 
    // protocol_fee_address: Address;
    reserve0: Int as coins;
    reserve1: Int as coins; 
    // // jetton_lp_wallet_code: Cell;
    // // lp_account_code: Cell;

    init(routerAddress: Address, token0Address: Address, token1Address: Address, reserve0: Int, reserve1: Int, totalSupplyLP: Int) {
        self.routerAddress = routerAddress;
        self.token0Address = token0Address;
        self.token1Address = token1Address;
        self.reserve0 = reserve0;
        self.reserve1 = reserve1;
        self.totalSupplyLP = totalSupplyLP;
    }

    receive(){}

    // receive(msg: BurnNotification) {
//         // throwUnless(INSUFFICIENT_GAS, (msg_value > gas_required) & (msg_value > cs~load_coins() * 6));
//         // throwUnless(INVALID_CALLER, equal_slices(calculate_user_jetton_lp_wallet_address(from_address, my_address(), storage::jetton_lp_wallet_code), sender_address));
//         throwUnless(ZERO_OUTPUT, msg.jetton_amount > 0);
//         let amount0_out = (msg.jetton_amount * self.reserve0) / self.total_supply_lp;
//         let amount1_out = (msg.jetton_amount * self.reserve1) / self.total_supply_lp;
//         throwUnless(ZERO_OUTPUT, (amount0_out > 0) && (amount1_out > 0));
//         self.reserve0 -= amount0_out;
//         self.reserve1 -= amount1_out;
//         self.total_supply_lp -= msg.jetton_amount;
        
//         let gas = 0;
//         let mode = SendRemainingValue;
//         // TODO: send excesses

//         message(MessageParamaters{
//             to: self.router_address,
//             value: gas,
//             mode: mode,
//             bounce: false,
//             body: PayTo{
//                 query_id: msg.query_id,
//                 exit_code: , // TODO
//                 to_address: msg.from_address,
//                 amount0: amount0_out,
//                 token0Address: self.token0Address,
//                 amount1: amount1_out,
//                 token1Address: self.token1Address,
//             }.toCell()
//         });
//     }

    receive(msg: CbAddLiquidity) {
        let liquidity: Int = 0;
        let to: Address = myAddress(); // TODO fix

        if (self.totalSupplyLP == 0) {
            liquidity = sqrt(msg.amount0 * msg.amount1) / REQUIRED_MIN_LIQUIDITY;
            // to = addressNone() // TODO 
        } else {
            let toMint0 = (msg.amount0 * self.totalSupplyLP) / self.reserve0;
            let toMint1 = (msg.amount1 * self.totalSupplyLP) / self.reserve1;
            liquidity = min(toMint0, toMint1);
            to = msg.userAddress;
        }

        self.reserve0 += msg.amount0;
        self.reserve1 += msg.amount1;
        self.totalSupplyLP += liquidity;

        if ((liquidity < msg.minLPOut) || ((self.reserve0 > MAX_COINS) || (self.reserve1 > MAX_COINS))) {
            message(MessageParameters{
                to: sender(),
                value: 0,
                bounce: false,
                mode: SendRemainingValue,
                body: AddLiquidity {
                    queryId: msg.queryId,
                    newAmount0: msg.amount0,
                    newAmount1: msg.amount1,
                    minLPOut: 0
                }.toCell()
            });
        } else {
            let lpWalletAddress = getLPWalletAddress(to, myAddress());
            message(MessageParameters{
                to: lpWalletAddress,
                value: 0,
                mode: SendRemainingValue,
                bounce: false,
                body: JettonTransferInternal {
                    queryId: msg.queryId,
                    amount: liquidity,
                    sender: myAddress(),
                    responseDestination: to,
                    forwardTonAmount: 0,
                    forwardPayload: emptySlice()
                }.toCell() 
            });
        }
    }

    receive(msg: CbRefundMe) {
        let lpAccountAddress = getLPAccountAddress(msg.userAddress, myAddress());
        throwUnless(INVALID_CALLER, lpAccountAddress == sender());
        message(MessageParameters{
            to: self.routerAddress,
            value: 0,
            mode: SendRemainingValue,
            bounce: false,
            body: PayTo{
                queryId: msg.queryId,
                toAddress: msg.userAddress,
                exitCode: REFUND_OK,
                amount0Out: msg.amount0,
                token0Address: self.token0Address,
                amount1Out: msg.amount1,
                token1Address: self.token1Address
            }.toCell()
        });
    }

//     receive(msg: CollectFees) {
//         let reward0 = self.collected_token0_protocol_fee / 1000;
//         let reward1 = self.collected_token1_protocol_fee / 1000;
        
//         // call_pay_to(gas * 3, NORMAL, query_id, storage::protocol_fee_address, 0, storage::collected_token0_protocol_fee, storage::collected_token1_protocol_fee); ;; revert if fails
//         // call_pay_to(gas, IGNORE_ERRORS, query_id, sender_address, 0, reward0, reward1);

//         self.collected_token0_protocol_fee -= reward0;
//         self.collected_token1_protocol_fee -= reward1;

//     }

    // TODO fees
    receive(msg: Swap) {
        throwUnless(WRONG_CALLER, sender() == self.routerAddress);

        let output: Int = 0;
        let tmpAmount0: Int = 0;
        let tmpAmount1: Int = 0;
        if (msg.tokenWallet == self.token0Address) {
            output = getAmountOut(msg.jettonAmount, self.reserve0, self.reserve1);
            tmpAmount0 = msg.jettonAmount;
        } else {
            output = getAmountOut(msg.jettonAmount, self.reserve1, self.reserve0);
            tmpAmount1 = msg.jettonAmount;
        }

        if ((self.totalSupplyLP <= 0) || (output <= 0) || (msg.minOutput >= output)) {
            message(MessageParameters{
                to: self.routerAddress,
                value: 0,
                mode: SendRemainingValue,
                bounce: false,
                body: PayTo{
                    queryId: msg.queryId,
                    toAddress: msg.fromAddress,
                    exitCode: SWAP_REFUND_NO_LIQ,
                    amount0Out: tmpAmount0,
                    token0Address: self.token0Address,
                    amount1Out: tmpAmount1,
                    token1Address: self.token1Address,
                }.toCell()
            });
            return;
        }

        if (tmpAmount0 > 0) {
            self.reserve0 += msg.jettonAmount;
            self.reserve1 -= output;

            if ((self.reserve0 > MAX_COINS) || (self.reserve1 <= 0)) {
                message(MessageParameters{
                    to: self.routerAddress,
                    value: 0,
                    mode: SendRemainingValue,
                    bounce: false,
                    body: PayTo{
                        queryId: msg.queryId,
                        toAddress: msg.fromAddress,
                        exitCode: SWAP_REFUND_RESERVE_ERR,
                        amount0Out: tmpAmount0,
                        token0Address: self.token0Address,
                        amount1Out: tmpAmount1,
                        token1Address: self.token1Address,
                    }.toCell()
                });
                return;
            }
            message(MessageParameters{
                to: self.routerAddress,
                value: 0,
                mode: SendRemainingValue,
                bounce: false,
                body: PayTo{
                    queryId: msg.queryId,
                    toAddress: msg.fromAddress,
                    exitCode: SWAP_OK,
                    amount0Out: 0,
                    token0Address: self.token0Address,
                    amount1Out: output,
                    token1Address: self.token1Address,
                }.toCell()
            });
        } else {
            self.reserve1 += msg.jettonAmount;
            self.reserve0 -= output;

            if ((self.reserve1 > MAX_COINS) || (self.reserve0 <= 0)) {
                message(MessageParameters{
                    to: self.routerAddress,
                    value: 0,
                    mode: SendRemainingValue,
                    bounce: false,
                    body: PayTo{
                        queryId: msg.queryId,
                        toAddress: msg.fromAddress,
                        exitCode: SWAP_REFUND_RESERVE_ERR,
                        amount0Out: tmpAmount0,
                        token0Address: self.token0Address,
                        amount1Out: tmpAmount1,
                        token1Address: self.token1Address,
                    }.toCell()
                });
                return;
            }
            message(MessageParameters{
                to: self.routerAddress,
                value: 0,
                mode: SendRemainingValue,
                bounce: false,
                body: PayTo{
                    queryId: msg.queryId,
                    toAddress: msg.fromAddress,
                    exitCode: SWAP_OK,
                    amount0Out: output,
                    token0Address: self.token0Address,
                    amount1Out: 0,
                    token1Address: self.token1Address,
                }.toCell()
            });
        }
    }

    receive(msg: ProvideLP) {
        throwUnless(WRONG_CALLER, sender() == self.routerAddress);
        let lpAccountAddress: Address = getLPAccountAddress(msg.fromUser, myAddress());
        message(MessageParameters{
            to: lpAccountAddress,
            value: 0,
            mode: SendRemainingValue,
            bounce: false,
            body: AddLiquidity{
                queryId: msg.queryId,
                newAmount0: msg.amount0,
                newAmount1: msg.amount1,
                minLPOut: msg.minLPOut
            }.toCell()
        }); 
    }

//     receive(msg: ResetGas) {

//     }

//     receive(msg: SetFees) {

//     }
}