import "./pool";
import "../base-tact/gas";

contract Router {
    receive(msg: PayTo) {
        let gasRequired = getGasFee(20000, WORKCHAIN); 
        let msgValue = context().value;
        throwUnless(INSUFFICIENT_GAS, msgValue > gasRequired);

        let poolAddress = getPoolAddress(msg.token0Address, msg.token1Address);
        throwUnless(INVALID_CALLER, poolAddress == sender());

        let gas = 0;
        let mode = SendRemainingValue;
        if ((msg.amount0Out > 0) && (msg.amount1Out > 0)) {
            gas = (msgValue - gasRequired) / 2;
            mode = SendDefaultMode;
        }
        if (msg.amount0Out > 0) {
            message(MessageParameters{
                to: msg.token0Address,
                value: gas,
                mode: mode,
                bounce: false,
                body: JettonTransfer {
                    queryId: msg.queryId,
                    amount: msg.amount0Out,
                    destination: msg.toAddress,
                    responseDestination: msg.toAddress,
                    customPayload: null,
                    forwardTonAmount: 0,
                    forwardPayload: emptySlice(),
                }.toCell()
            });
        }
        if (msg.amount1Out > 0) {
            message(MessageParameters{
                to: msg.token1Address,
                value: gas,
                mode: mode,
                bounce: false, 
                body: JettonTransfer {
                    queryId: msg.queryId,
                    amount: msg.amount1Out,
                    destination: msg.toAddress,
                    responseDestination: msg.toAddress,
                    customPayload: null,
                    forwardTonAmount: 0,
                    forwardPayload: emptySlice(),
                }.toCell()
            });
        }
    }

    receive(msg: JettonNotification) {
        throwUnless(INVALID_AMOUNT, msg.amount > 0);
        let payload: Slice = msg.forwardPayload;
        let opcode: Int = payload.loadUint(32);
        let token1Address: Address = payload.loadAddress();
        let ctx: Context = context();
        let fwdFee = ctx.readForwardFee();
        if ((fwdFee * 6 > ctx.value) || token1Address == ctx.sender || self.isLocked) {
            message(MessageParameters{
                to: ctx.sender,
                value: 0,
                mode: SendRemainingValue,
                bounce: false,
                body: JettonTransfer {
                    queryId: msg.queryId,
                    amount: msg.amount,
                    destination: ctx.sender,
                    responseDestination: ctx.sender,
                    customPayload: null, 
                    forwardTonAmount: 0,
                    forwardPayload: emptySlice(),
                }.toCell()
            });
        } else {
            if (opcode == SWAP) {
                let sqrtPriceLimitX96 = payload.loadUint(160);
                let poolAddress: Address = getPoolAddress(ctx.sender, token1Address);
                message(MessageParameters{
                    to: poolAddress,
                    value: 0,
                    mode: SendRemainingValue,
                    bounce: false,
                    body: Swap {
                        userAddress: msg.sender,
                        zeroForOne: ctx.sender.asSlice().hash() > token1Address.asSlice().hash(),
                        amountSpecified: msg.amount,
                        sqrtPriceLimitX96: sqrtPriceLimitX96
                    }.toCell()
                });
            } else if (opcode == PROVIDE_LP) {
                let poolInit: StateInit = getPoolStateInit(ctx.sender, token1Address);
                let enough0 = payload.loadCoins();
                let enough1 = payload.loadCoins();
                let liquidity = payload.loadUint(128);
                let lowerTick = payload.loadInt(24);
                let upperTick = payload.loadInt(24);
                if (ctx.sender.asSlice().hash() > token1Address.asSlice().hash()) {
                    deploy(DeployParameters{
                        init: poolInit,
                        value: 0,
                        mode: SendRemainingValue,
                        bounce: false,
                        body: ProvideLiquidity {
                            userAddress: msg.sender,
                            amount0: msg.amount, 
                            amount1: 0,
                            enough0: enough0,
                            enough1: enough1,
                            liquidity: liquidity,
                            lowerTick: lowerTick,
                            upperTick: upperTick,
                        }.toCell()
                    }); 
                } else {
                    deploy(DeployParameters{
                        init: poolInit,
                        value: 0,
                        mode: SendRemainingValue,
                        bounce: false,
                        body: ProvideLiquidity {
                            userAddress: msg.sender,
                            amount0: 0, 
                            amount1: msg.amount,
                            enough0: enough0,
                            enough1: enough1,
                            liquidity: liquidity,
                            lowerTick: lowerTick,
                            upperTick: upperTick,
                        }.toCell()
                    }); 
                }  
            }
        }
    }
}