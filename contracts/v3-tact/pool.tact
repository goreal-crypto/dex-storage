import "./lp_account";
import "./position";
import "./libraries/sqrt_price_math";
import "./libraries/tick_math";
import "./libraries/tick_bitmap";
import "./libraries/swap_math";

message(1) ProvideLiquidity {
    userAddress: Address;
    amount0: Int as coins;
    amount1: Int as coins;
    enough0: Int as coins;
    enough1: Int as coins;
    liquidity: Int as uint128;
    tickLower: Int as int24;
    tickUpper: Int as int24;
}

message(2) MintLiquidity {
    userAddress: Address;
    amount0: Int as coins;
    amount1: Int as coins;
    liquidity: Int as uint128;
    tickLower: Int as int24;
    tickUpper: Int as int24;
}

message(3) Swap {
    userAddress: Address;
    zeroForOne: Bool;
    amountSpecified: Int as int256;
    sqrtPriceLimitX96: Int as uint160;
}

message Initialize {
    sqrtPriceX96: Int as uint160;
}

struct SwapState {
    amountSpecifiedRemaining: Int as int256;
    amountCalculated: Int as int256;
    sqrtPriceX96: Int as uint160;
    tick: Int as int24;
    liquidity: Int as uint128;
} 

struct PoolState {
    routerAddress: Address;
    token0Address: Address;
    token1Address: Address;
    tick: Int as int24;
    liquidity: Int as uint128;
    sqrtPriceX96: Int as uint160;
    ticks: map<Int as int24, TickInfo>;
    tickSpacing: Int as int24;
}

struct Amounts {
    amount0: Int as coins;
    amount1: Int as coins;
}

const MIN_TICK: Int = -80000;
const MAX_TICK: Int = 80000;
const WRONG_CALLER: Int = 10000;
const INVALID_AMOUNT: Int = 10001;

contract Pool(
    routerAddress: Address,
    token0Address: Address,
    token1Address: Address,
    tick: Int as int24,
    liquidity: Int as uint128,
    sqrtPriceX96: Int as uint160,
    ticks: map<Int as int24, TickInfo>,
    tickSpacing: Int as int24,
    positionCounter: Int as uint64) {

    receive(msg: Initialize) {
        self.sqrtPriceX96 = msg.sqrtPriceX96;
        self.tick = tickAtSqrtRatio(msg.sqrtPriceX96);
    }

    receive(msg: Swap) {
        let slot0StartSqrtPriceX96 = self.sqrtPriceX96;
        let slot0StartTick = self.tick;
        let exactInput = msg.amountSpecified > 0;
        let state = SwapState{
            amountSpecifiedRemaining: msg.amountSpecified,
            amountCalculated: 0,
            sqrtPriceX96: slot0StartSqrtPriceX96,
            tick: slot0StartTick,
            liquidity: self.liquidity
        };
        while (state.amountSpecifiedRemaining != 0 && state.sqrtPriceX96 != msg.sqrtPriceLimitX96) {
            // dump(state.liquidity);
            dump(state.tick);
            let stepSqrtPriceStartX96 = state.sqrtPriceX96;
            let stepNextTick = nextInitializedTick(state.tick, self.ticks, msg.zeroForOne, self.tickSpacing);
            if (stepNextTick.tick < MIN_TICK) {
                stepNextTick.tick = MIN_TICK;
            } else if (stepNextTick.tick > MAX_TICK) {
                stepNextTick.tick = MAX_TICK;
            }
            // dump(stepNextTick.tick);
            // dump(stepNextTick.initialized);
            let stepSqrtPriceNextX96 = sqrtRatioAtTick(stepNextTick.tick);
            let step = computeSwapStep(
                state.sqrtPriceX96,
                (msg.zeroForOne ? stepSqrtPriceNextX96 < msg.sqrtPriceLimitX96 : stepSqrtPriceNextX96 > msg.sqrtPriceLimitX96)
                    ? msg.sqrtPriceLimitX96
                    : stepSqrtPriceNextX96,
                state.liquidity,
                state.amountSpecifiedRemaining,
                0
            );
            state.sqrtPriceX96 = step.sqrtRatioNextX96;
            dump(step.amountIn);
            dump(step.amountOut);
            // dump(step.feeAmount);
            // dump(state.amountSpecifiedRemaining);
            if (exactInput) {
                state.amountSpecifiedRemaining -= (step.amountIn + step.feeAmount);
                state.amountCalculated -= step.amountOut    
            } else {
                state.amountSpecifiedRemaining += step.amountOut;
                state.amountCalculated += step.amountIn + step.feeAmount; 
            }
            // dump(state.amountSpecifiedRemaining);

            // if (cache.feeProtocol > 0) {
            //     uint256 delta = step.feeAmount / cache.feeProtocol;
            //     step.feeAmount -= delta;
            //     state.protocolFee += uint128(delta);
            // }
            // // update global fee tracker
            // if (state.liquidity > 0)
            //     state.feeGrowthGlobalX128 += FullMath.mulDiv(step.feeAmount, FixedPoint128.Q128, state.liquidity);
            // dump(state.sqrtPriceX96);
            // dump(stepSqrtPriceNextX96);
            if (state.sqrtPriceX96 == stepSqrtPriceNextX96) {
                if (stepNextTick.initialized) {
                    let liquidityNet = self.ticks.get(stepNextTick.tick)!!.liquidityNet;
                    if (msg.zeroForOne) {
                        liquidityNet = -liquidityNet;
                    }
                    state.liquidity += liquidityNet;
                    // dump(liquidityNet);
                }
                state.tick = msg.zeroForOne ? stepNextTick.tick - 1 : stepNextTick.tick;
            } else if (state.sqrtPriceX96 != stepSqrtPriceStartX96) {
                state.tick = tickAtSqrtRatio(state.sqrtPriceX96);
            }
            // dump(state.tick);
            // dump(state.liquidity);
        }
        if (state.tick != slot0StartTick) {
            self.tick = state.tick;
            self.sqrtPriceX96 = state.sqrtPriceX96;
        } else {
            self.sqrtPriceX96 = state.sqrtPriceX96;
        }
        if (self.liquidity != state.liquidity) {
            self.liquidity = state.liquidity;
        }
    }

    receive(msg: ProvideLiquidity) {
        throwUnless(WRONG_CALLER, sender() == self.routerAddress);
        let LPAccountInit: StateInit = getLPAccountStateInit(msg.userAddress, myAddress());
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
        // throwUnless(WRONG_CALLER, sender() == contractAddress(getLPAccountStateInit(msg.userAddress, myAddress())));
        // _updatePosition
        let flippedLower: Bool = false;
        let flippedUpper: Bool = false;
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
                dump(self.liquidity);
                dump(msg.liquidity);
                self.liquidity += msg.liquidity;
            } else {
                amount1 = amount1Delta(
                    sqrtRatioAtTick(msg.tickLower),
                    sqrtRatioAtTick(msg.tickUpper),
                    msg.liquidity
                );
            }
        }
        // dump(msg.amount0);
        // dump(msg.amount1);
        // dump(amount0);
        // dump(amount1);
        throwUnless(INVALID_AMOUNT, msg.amount0 >= amount0 && msg.amount1 >= amount1);
        let positionStateInit: StateInit = getPositionStateInit(self.positionCounter, msg.userAddress, myAddress());
        deploy(DeployParameters{
            init: positionStateInit,
            value: 0,
            mode: SendRemainingValue,
            bounce: false,
            body: PositionInit {
                tickLower: msg.tickLower,
                tickUpper: msg.tickUpper,
                liquidity: msg.liquidity,
            }.toCell(),
        });
        self.positionCounter += 1;
    }

    receive(msg: PositionBurnNotification) {
        let positionStateInit: StateInit = getPositionStateInit(msg.index, msg.userAddress, myAddress());
    }

    fun updateTicks(tick: Int, liquidityDelta: Int, upper: Bool): Bool {
        let tickInfoMaybe: TickInfo? = self.ticks.get(tick);
        let tickInfo: TickInfo = tickInfoMaybe == null ? TickInfo{liquidityGross: 0, liquidityNet: 0} : tickInfoMaybe!!;
        let liquidityGrossBefore: Int = tickInfo.liquidityGross;
        let liquidityGrossAfter: Int = liquidityGrossBefore + liquidityDelta;
        let flipped: Bool = (liquidityGrossAfter == 0) != (liquidityGrossBefore == 0);
        tickInfo.liquidityGross = liquidityGrossAfter;
        tickInfo.liquidityNet = upper 
                                ? tickInfo.liquidityNet - liquidityDelta
                                : tickInfo.liquidityNet + liquidityDelta;
        self.ticks.set(tick, tickInfo);
        return flipped;
    }

    get fun getPoolState(): PoolState {
        return PoolState{
            routerAddress: self.routerAddress,
            token0Address: self.token0Address,
            token1Address: self.token1Address,
            tick: self.tick,
            sqrtPriceX96: self.sqrtPriceX96,
            liquidity: self.liquidity,
            ticks: self.ticks,
            tickSpacing: self.tickSpacing,
        };
    }

    get fun getMintEstimate(tickLower: Int, tickUpper: Int, liquidity: Int): Amounts {
        let amounts = Amounts{
            amount0: 0,
            amount1: 0,
        };
        if (liquidity != 0) { // is this neccessary?
            if (self.tick < tickLower) {
                amounts.amount0 = amount0Delta(
                    sqrtRatioAtTick(tickLower),
                    sqrtRatioAtTick(tickUpper),
                    liquidity
                );
            } else if (self.tick < tickUpper) {
                amounts.amount0 = amount0Delta(
                    self.sqrtPriceX96,
                    sqrtRatioAtTick(tickUpper),
                    liquidity
                );
                amounts.amount1 = amount1Delta(
                    sqrtRatioAtTick(tickLower),
                    self.sqrtPriceX96,
                    liquidity
                );
            } else {
                amounts.amount1 = amount1Delta(
                    sqrtRatioAtTick(tickLower),
                    sqrtRatioAtTick(tickUpper),
                    liquidity
                );
            }
        }
        return amounts;
    }

}

inline fun getPositionStateInit(index: Int, userAddress: Address, poolAddress: Address): StateInit {
    return initOf Position(
        index,
        userAddress,
        poolAddress,
        0,
        0,
        0,
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