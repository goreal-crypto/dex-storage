import "./lp_account";
import "./messages";
import "./lp_wallet";
import "./gas";

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

struct AmountOut {
    out: Int as coins; 
    protocolFeeOut: Int as coins;
    refFeeOut: Int as coins;
}


contract Pool {
    routerAddress: Address;
    LPFee: Int as uint8;
    protocolFee: Int as uint8;
    refFee: Int as uint8;
    token0Address: Address;
    token1Address: Address;
    totalSupplyLP: Int as coins; 
    collectedToken0ProtocolFee: Int as coins;
    collectedToken1ProtocolFee: Int as coins; 
    protocolFeeAddress: Address;
    reserve0: Int as coins;
    reserve1: Int as coins; 

    init(
        routerAddress: Address,
        LPFee: Int as uint8,
        protocolFee: Int as uint8,
        refFee: Int as uint8,
        token0Address: Address,
        token1Address: Address,
        totalSupplyLP: Int as coins,
        collectedToken0ProtocolFee: Int as coins,
        collectedToken1ProtocolFee: Int as coins,
        protocolFeeAddress: Address,
        reserve0: Int as coins,
        reserve1: Int as coins
    ) {
        self.routerAddress = routerAddress;
        self.LPFee = LPFee;
        self.protocolFee = protocolFee;
        self.refFee = refFee;
        self.token0Address = token0Address;
        self.token1Address = token1Address;
        self.totalSupplyLP = totalSupplyLP;
        self.collectedToken0ProtocolFee = collectedToken0ProtocolFee;
        self.collectedToken1ProtocolFee = collectedToken1ProtocolFee;
        self.protocolFeeAddress = protocolFeeAddress;
        self.reserve0 = reserve0;
        self.reserve1 = reserve1;
    }

    receive(){}


    inline fun getAmountOut(hasRef: Bool, amountIn: Int, reserveIn: Int, reserveOut: Int): AmountOut {
        // let baseOut: Int = (amountIn * reserveOut) / (reserveIn + amountIn);
        let amountInWithFee: Int = amountIn * (FEE_DIVIDER - self.LPFee);
        let baseOut: Int = (amountInWithFee * reserveOut) / (reserveIn * FEE_DIVIDER + amountInWithFee);
        let protocolFeeOut: Int = 0;
        let refFeeOut: Int = 0;
        if (self.protocolFee > 0) {
            protocolFeeOut =  divc(baseOut * self.protocol_fee, FEE_DIVIDER)
        }
        if (hasRef && (self.refFee > 0)) {
            refFeeOut = divc(baseOut * self.refFee, FEE_DIVIDER);
        }
        
        baseOut -= protocolFeeOut + refFeeOut;
                
        return AmountOut{
            out: baseOut,
            protocolFeeOut: protocolFeeOut,
            refFeeOut: refFeeOut
        };
    }

    // receive(msg: JettonBurnNotification) {
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
        let to: Address; 

        if (self.totalSupplyLP == 0) {
            liquidity = sqrt(msg.amount0 * msg.amount1) / REQUIRED_MIN_LIQUIDITY;
            to = emptyAddress() 
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
                    minLPOut: 0,
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
                    forwardPayload: emptySlice(),
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
                token1Address: self.token1Address,
            }.toCell()
        });
    }
    
    receive(msg: CollectFees) {
        throwUnless(NO_LIQUIDITY, self.totalSupplyLP > REQUIRED_MIN_LIQUIDITY);
        throwUnless(LOW_LIQUIDITY, (self.collectedToken0ProtocolFee > REQUIRED_MIN_COLLECT_FEES) &&
                                   (self.collectedToken1ProtocolFee > REQUIRED_MIN_COLLECT_FEES));

        let msgValue = context().value;
        let gasRequired = getGasFee(40000, WORKCHAIN);
        throwUnless(INSUFFICIENT_GAS, (msgValue - gasRequired) > 1000000000); // 1 ton
        let gas = (msgValue - gasRequired) / 4;
        let reward0 = self.collectedToken0ProtocolFee / 1000;
        let reward1 = self.collectedToken1ProtocolFee / 1000;
        self.collectedToken0ProtocolFee -= reward0;
        self.collectedToken1ProtocolFee -= reward1;

        throwUnless(ZERO_OUTPUT, (reward0 > 0) && (reward1 > 0));
        throwUnless(ZERO_OUTPUT, (self.collectedToken0ProtocolFee > 0) && 
                                 (self.collectedToken1ProtocolFee > 0));

        message(MessageParameters{
            to: self.routerAddress,
            value: gas * 3,
            mode: SendDefaultMode,
            bounce: true,
            body: PayTo {
                queryId: msg.queryId,
                toAddress: self.protocolFeeAddress,
                exitCode: 0,
                amount0Out: self.collectedToken0ProtocolFee,
                token0Address: self.token0Address,
                amount1Out: self.collectedToken1ProtocolFee,
                token1Address: self.token1Address,
            }.toCell(),
        });

        message(MessageParameters{
            to: self.routerAddress,
            value: gas,
            mode: SendDefaultMode,
            bounce: true,
            body: PayTo {
                queryId: msg.queryId,
                toAddress: sender(),
                exitCode: 0,
                amount0Out: reward0,
                token0Address: self.token0Address,
                amount1Out: reward1,
                token1Address: self.token1Address,
            }.toCell(),
        });

        self.collectedToken0ProtocolFee = 0;
        self.collectedToken1ProtocolFee = 0;

    }

    receive(msg: Swap) {
        throwUnless(WRONG_CALLER, sender() == self.routerAddress);

        let refAddress: Address = emptyAddress();
        let tmpAmount0: Int = 0;
        let tmpAmount1: Int = 0;

        let mode = SendRemainingValue;
        let gas: Int = 0;

        let amountOut: AmountOut;

        if (msg.hasRef) {
            mode = SendDefaultMode;
            gas = (context().value - getGasFee(25000, WORKCHAIN)) / 2;
            refAddress = msg.refAddress!!;
        }

        if (msg.tokenWallet == self.token0Address) {
            amountOut = getAmountOut(msg.jettonAmount, self.reserve0, self.reserve1);
            tmpAmount0 = msg.jettonAmount;
        } else {
            amountOut = getAmountOut(msg.jettonAmount, self.reserve1, self.reserve0);
            tmpAmount1 = msg.jettonAmount;
        }

        if ((self.totalSupplyLP <= 0) || (amountOut.out <= 0) || (msg.minOutput >= amountOut.out)) {
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
            self.reserve1 -= (amountOut.out + amountOut.protocolFeeOut + amountOut.refFeeOut);
            self.collectedToken1ProtocolFee += amountOut.protocolFeeOut;

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
            if (mode == SendDefaultMode) {
                message(MessageParameters{
                    to: self.routerAddress,
                    value: gas,
                    mode: mode,
                    bounce: false,
                    body: PayTo{
                        queryId: msg.queryId,
                        toAddress: msg.refAddress,
                        exitCode: SWAP_OK_REF,
                        amount0Out: 0,
                        token0Address: self.token0Address,
                        amount1Out: amountOut.refFeeOut,
                        token1Address: self.token1Address,
                    }.toCell()
                });
            }
            message(MessageParameters{
                to: self.routerAddress,
                value: gas,
                mode: mode,
                bounce: false,
                body: PayTo{
                    queryId: msg.queryId,
                    toAddress: msg.fromAddress,
                    exitCode: SWAP_OK,
                    amount0Out: 0,
                    token0Address: self.token0Address,
                    amount1Out: amountOut.out,
                    token1Address: self.token1Address,
                }.toCell()
            });
        } else {
            self.reserve1 += msg.jettonAmount;
            self.reserve0 -= (amountOut.out + amountOut.protocolFeeOut + amountOut.refFeeOut);
            self.collectedToken0ProtocolFee += amountOut.protocolFeeOut;

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

            if (mode == SendDefaultMode) {
                message(MessageParameters{
                    to: self.routerAddress,
                    value: gas,
                    mode: mode,
                    bounce: false,
                    body: PayTo{
                        queryId: msg.queryId,
                        toAddress: msg.refAddress,
                        exitCode: SWAP_OK_REF,
                        amount0Out: amountOut.refFeeOut,
                        token0Address: self.token0Address,
                        amount1Out: 0,
                        token1Address: self.token1Address,
                    }.toCell()
                });
            }
            message(MessageParameters{
                to: self.routerAddress,
                value: gas,
                mode: mode,
                bounce: false,
                body: PayTo{
                    queryId: msg.queryId,
                    toAddress: msg.fromAddress,
                    exitCode: SWAP_OK,
                    amount0Out: amountOut.out,
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
                minLPOut: msg.minLPOut,
            }.toCell()
        }); 
    }


// TODO 
//     receive(msg: ResetGas) {

//     }

//     receive(msg: SetFees) {

//     }
}