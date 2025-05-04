import "./pool";

contract Router {
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
                    customPayload: null, // .store_uint(0, 1);
                    forwardTonAmount: 0,
                    forwardPayload: emptySlice(), // .store_uint(0, 1);
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