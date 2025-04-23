import "./lp_account";
import "./position";
import "./libraries/sqrt_price_math";
import "./libraries/tick_math";

struct Tick {
    liquidityGross: Int as uint128;
    liquidityNet: Int as int128;
}

message ProvideLiquidity {
    userAddress: Address;
    amount0: Int as coins;
    amount1: Int as coins;
    enough0: Int as coins;
    enough1: Int as coins;
    liquidity: Int as uint128;
    tickLower: Int as int24;
    tickUpper: Int as int24;
}

message MintLiquidity {
    userAddress: Address;
    amount0: Int as coins;
    amount1: Int as coins;
    liquidity: Int as uint128;
    tickLower: Int as int24;
    tickUpper: Int as int24;
}

contract V3Pool {
    routerAddress: Address;
    token0Address: Address;
    token1Address: Address;
    tick: Int as int24;
    liquidity: Int as uint128;
    sqrtPriceX96: Int as uint160;
    ticks: map<Int as int24, Tick>;
    tickSpacing: Int as int24;

    receive(msg: Swap) {
        throwUnless(WRONG_CALLER, sender() == self.routerAddress);

        let zeroForOne = msg.zeroForOne;
        let exactIn = msg.amountSpecified >= 0;
        let mut amountRemaining = abs(msg.amountSpecified);
        let mut sqrtPrice = self.sqrtPriceX96;
        let mut tick = self.tick;
        let mut liquidity = self.liquidity;
        let sqrtPriceLimit = msg.sqrtPriceLimitX96;

        let mut amountInTotal = 0;
        let mut amountOutTotal = 0;

        while (amountRemaining > 0 && (zeroForOne ? sqrtPrice > sqrtPriceLimit : sqrtPrice < sqrtPriceLimit)) {
            let (nextTick, initialized) = findNextInitializedTick(tick, zeroForOne);
            let sqrtPriceNext = sqrtRatioAtTick(nextTick);

            let targetPrice = zeroForOne ? max(sqrtPriceLimit, sqrtPriceNext) : min(sqrtPriceLimit, sqrtPriceNext);

            let (newSqrtPrice, amountIn, amountOut) = computeSwapStep(zeroForOne, sqrtPrice, targetPrice, liquidity, amountRemaining, exactIn);

            sqrtPrice = newSqrtPrice;
            amountRemaining -= amountIn;
            amountInTotal += amountIn;
            amountOutTotal += amountOut;

            if (sqrtPrice == sqrtPriceNext) {
                let tickInfo = self.ticks.get(nextTick)!!;
                liquidity = zeroForOne ? (liquidity - tickInfo.liquidityNet) : (liquidity + tickInfo.liquidityNet);
                tick = zeroForOne ? (nextTick - 1) : nextTick;
            } else {
                tick = tickAtSqrtRatio(sqrtPrice);
            }
        }

        self.sqrtPriceX96 = sqrtPrice;
        self.tick = tick;
        self.liquidity = liquidity;

        if (zeroForOne) {
            send(SendParameters{
                to: msg.userAddress,
                value: 0,
                mode: SendRemainingValue,
                body: TransferToken1{
                    amount: amountOutTotal
                }.toCell()
            });
        } else {
            send(SendParameters{
                to: msg.userAddress,
                value: 0,
                mode: SendRemainingValue,
                body: TransferToken0{
                    amount: amountOutTotal
                }.toCell()
            });
        }
    }
    
    fun findNextInitializedTick(tick: Int, zeroForOne: Bool): (Int, Bool) {
        let i = tick;
        loop {
            i = zeroForOne ? (i - self.tickSpacing) : (i + self.tickSpacing);
            let exists = self.ticks.contains(i);
            if (exists || abs(i) > 887272) {
                return (i, exists);
            }
        }
    }


    receive(msg: ProvideLiquidity) {
        throwUnless(WRONG_CALLER, sender() == self.routerAddress);
        let LPAccountInit: StateInit = getLPAccountStateInit(msg.fromUser, myAddress());
        deploy(DeployParameters{
            init: LPAccountInit,
            value: 0,
            mode: SendRemainingValue,
            bounce: false,
            body: AddLiquidity{
                newAmount0: msg.amount0,
                newAmount1: msg.amount1,
                newEnough0: msg.enough0,
                newEnough1: msg.enough1,
                liquidity: msg.liquidity,
                tickLower: msg.tickLower,
                tickUpper: msg.tickUpper,
            }.toCell()
        }); 
    }

    receive(msg: MintLiquidity) {
        throwUnless(WRONG_CALLER, sender() == contractAddress(getLPAccountStateInit(msg.userAddress, myAddress())));
        
        // _updatePosition
        let flippedLower: Bool;
        let flippedUpper: Bool;
        if (msg.liquidity != 0) { // is this neccessary?
            flippedLower = self.updateTicks(msg.tickLower, msg.liquidity, false);
            flippedUpper = self.updateTicks(msg.tickUpper, msg.liquidity, true);
            // if (flippedLower) {
            //     tickBitmap.flipTick(tickLower, tickSpacing);
            // }
            // if (flippedUpper) {
            //     tickBitmap.flipTick(tickUpper, tickSpacing);
            // }
        }

        let amount0: Int = 0;
        let amount1: Int = 0;

        if (msg.liquidity != 0) { // is this neccessary?
            if (self.tick < msg.tickLower) {
                amount0 = amount0Delta(
                    sqrtRatioAtTick(msg.tickLower),
                    sqrtRatioAtTick(msg.tickUpper),
                    msg.liquidity
                );
            } else if (self.tick < msg.tickUpper) {
                amount0 = amount0Delta(
                    self.sqrtPriceX96,
                    sqrtRatioAtTick(msg.tickUpper),
                    msg.liquidity
                );
                amount1 = amount1Delta(
                    sqrtRatioAtTick(msg.tickLower),
                    self.sqrtPriceX96,
                    msg.liquidity
                );
                self.liquidity += msg.liquidity;
            } else {
                amount1 = amount1Delta(
                    sqrtRatioAtTick(msg.tickLower),
                    sqrtRatioAtTick(msg.tickUpper),
                    msg.liquidity
                );
            }
        }
        throwUnless(INVALID_AMOUNT, msg.amount0 >= amount0 && msg.amount1 >= amount1);
        let positionStateInit: StateInit = getPositionStateInit(msg.userAddress, myAddress(), msg.tickLower, msg.tickUpper, msg.liquidity);
        deploy(DeployParameters{
            init: positionStateInit,
            value: 0,
            mode: SendRemainingValue,
            bounce: false,
            body: null,
        });
    }

    receive(msg: BurnLiquidity) {
        
    }

    fun updateTicks(tick: Int, liquidityDelta: Int, upper: Bool): Bool {
        let tickInfoMaybe: Tick? = self.ticks.get(tick);
        let tickInfo: Tick = tickInfoMaybe == null ? Tick{liquidityGross: 0, liquidityNet: 0} : tickInfoMaybe!!;
        let liquidityGrossBefore: Int = tickInfo.liquidityGross;
        let liquidityGrossAfter: Int = liquidityGrossBefore + liquidityDelta;
        let flipped: Bool = (liquidityGrossAfter == 0) != (liquidityGrossBefore == 0);
        tickInfo.liquidityGross = liquidityGrossAfter;
        tickInfo.liquidityNet = upper 
                                ? tickInfo.liquidityNet - liquidityDelta
                                : tickInfo.liquidityNet + liquidityDelta;
        if (tickInfoMaybe == null) {
            self.ticks.set(tick, tickInfo);
        } else {
            self.ticks.replace(tick, tickInfo);
        }
        return flipped;
    }

}

inline fun getPositionStateInit(userAddress: Address, poolAddress: Address, tickLower: Int, tickUpper: Int, amount: Int): StateInit {
    return initOf Position(
        userAddress,
        poolAddress,
        tickLower,
        tickUpper,
        amount,
    );
}

inline fun getLPAccountStateInit(userAddress: Address, poolAddress: Address): StateInit {
    return initOf LPAccount(
        userAddress,
        poolAddress,
        0,
        0
    );
}