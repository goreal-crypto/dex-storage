import "./lp_account";
import "./position";
import "./libraries/sqrt_price_math";
import "./libraries/tick_math";
import "./libraries/tick_bitmap";
import "./libraries/swap_math";
import "./messages";

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
            let stepSqrtPriceStartX96 = state.sqrtPriceX96;
            let stepNextTick = nextInitializedTick(state.tick, self.ticks, msg.zeroForOne, self.tickSpacing);
            if (stepNextTick.tick < MIN_TICK) {
                stepNextTick.tick = MIN_TICK;
            } else if (stepNextTick.tick > MAX_TICK) {
                stepNextTick.tick = MAX_TICK;
            }
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
            if (exactInput) {
                state.amountSpecifiedRemaining -= (step.amountIn + step.feeAmount);
                state.amountCalculated -= step.amountOut    
            } else {
                state.amountSpecifiedRemaining += step.amountOut;
                state.amountCalculated += step.amountIn + step.feeAmount; 
            }
            // if (cache.feeProtocol > 0) {
            //     uint256 delta = step.feeAmount / cache.feeProtocol;
            //     step.feeAmount -= delta;
            //     state.protocolFee += uint128(delta);
            // }
            // // update global fee tracker
            // if (state.liquidity > 0)
            //     state.feeGrowthGlobalX128 += FullMath.mulDiv(step.feeAmount, FixedPoint128.Q128, state.liquidity);
            if (state.sqrtPriceX96 == stepSqrtPriceNextX96) {
                if (stepNextTick.initialized) {
                    let liquidityNet = self.ticks.get(stepNextTick.tick)!!.liquidityNet;
                    if (msg.zeroForOne) {
                        liquidityNet = -liquidityNet;
                    }
                    state.liquidity += liquidityNet;
                }
                state.tick = msg.zeroForOne ? stepNextTick.tick - 1 : stepNextTick.tick;
            } else if (state.sqrtPriceX96 != stepSqrtPriceStartX96) {
                state.tick = tickAtSqrtRatio(state.sqrtPriceX96);
            }
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
        // if (msg.zeroForOne) {
        //     feeGrowthGlobal0X128 = state.feeGrowthGlobalX128;
        //     if (state.protocolFee > 0) protocolFees.token0 += state.protocolFee;
        // } else {
        //     feeGrowthGlobal1X128 = state.feeGrowthGlobalX128;
        //     if (state.protocolFee > 0) protocolFees.token1 += state.protocolFee;
        // } 
        let result = Amounts {
            amount0: 0,
            amount1: 0,
        };
        if (msg.zeroForOne == exactInput) {
            result.amount0 = state.amountSpecifiedRemaining;
            result.amount1 = -state.amountCalculated;
        } else {
            result.amount0 = -state.amountCalculated;
            result.amount1 = state.amountSpecifiedRemaining;
        }
        message(MessageParameters{
            to: self.routerAddress,
            value: 0,
            mode: SendRemainingValue,
            bounce: false,
            body: PayTo{
                queryId: msg.queryId,
                toAddress: msg.userAddress,
                amount0Out: result.amount0,
                token0Address: self.token0Address,
                amount1Out: result.amount1,
                token1Address: self.token1Address,
            }.toCell()
        });

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
                queryId: msg.queryId,
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
        self.update(msg.tickLower, msg.tickUpper, msg.liquidity);
        let expected = self.amounts(msg.tickLower, msg.tickUpper, msg.liquidity);
        // dump(expected.amount0);
        // dump(msg.amount0);
        throwUnless(INVALID_AMOUNT, msg.amount0 >= expected.amount0 && msg.amount1 >= expected.amount1);
        let positionStateInit: StateInit = getPositionStateInit(self.positionCounter, msg.userAddress, myAddress(), msg.tickLower, msg.tickUpper);
        deploy(DeployParameters{
            init: positionStateInit,
            value: 0,
            mode: SendRemainingValue,
            bounce: false,
            body: PositionInit{
                queryId: msg.queryId,
                liquidity: msg.liquidity,
            }.toCell()
        });
        self.positionCounter += 1;
    }

    receive(msg: StartBurn) {
        let positionStateInit: StateInit = getPositionStateInit(msg.index, sender(), myAddress(), msg.tickLower, msg.tickUpper);
        message(MessageParameters{
            to: contractAddress(positionStateInit),
            value: 0,
            mode: SendRemainingValue,
            bounce: false,
            body: PositionBurn {
                queryId: msg.queryId,
                liquidity: msg.liquidity,
            }.toCell()
        });
    }

    receive(msg: PositionBurnNotification) {
        let positionStateInit: StateInit = getPositionStateInit(msg.index, msg.userAddress, myAddress(), msg.tickLower, msg.tickUpper);
        throwUnless(INVALID_CALLER, sender() == contractAddress(positionStateInit));
        self.update(msg.tickLower, msg.tickUpper, msg.liquidity);
        let amountsOut = self.amounts(msg.tickLower, msg.tickUpper, -msg.liquidity);
        message(MessageParameters{
            to: self.routerAddress,
            value: 0,
            mode: SendRemainingValue,
            bounce: false,
            body: PayTo{
                queryId: msg.queryId,
                toAddress: msg.userAddress,
                amount0Out: -amountsOut.amount0,
                token0Address: self.token0Address,
                amount1Out: -amountsOut.amount1,
                token1Address: self.token1Address,
            }.toCell()
        });
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
        return self.amounts(tickLower, tickUpper, liquidity);
    }

    fun update(tickLower: Int, tickUpper: Int, liquidity: Int) {
        let flippedLower: Bool = false;
        let flippedUpper: Bool = false;
        if (liquidity != 0) { 
            flippedLower = self.updateTicks(tickLower, liquidity, false);
            flippedUpper = self.updateTicks(tickUpper, liquidity, true);
        }
        if (liquidity < 0) {
            if (flippedLower) {
                self.ticks.del(tickLower);
            }
            if (flippedUpper) {
                self.ticks.del(tickUpper);
            }
        }
    }

    fun amounts(tickLower: Int, tickUpper: Int, liquidity: Int): Amounts {
        let result = Amounts{
            amount0: 0,
            amount1: 0,
        };
        if (liquidity != 0) { // is this neccessary?
            if (self.tick < tickLower) {
                result.amount0 = amount0Delta(
                    sqrtRatioAtTick(tickLower),
                    sqrtRatioAtTick(tickUpper),
                    liquidity
                );
            } else if (self.tick < tickUpper) {
                result.amount0 = amount0Delta(
                    self.sqrtPriceX96,
                    sqrtRatioAtTick(tickUpper),
                    liquidity
                );
                result.amount1 = amount1Delta(
                    sqrtRatioAtTick(tickLower),
                    self.sqrtPriceX96,
                    liquidity
                );
                self.liquidity += liquidity;
            } else {
                result.amount1 = amount1Delta(
                    sqrtRatioAtTick(tickLower),
                    sqrtRatioAtTick(tickUpper),
                    liquidity
                );
            }
        }
        return result;
    }
}

fun getPositionStateInit(index: Int, userAddress: Address, poolAddress: Address, tickLower: Int, tickUpper: Int): StateInit {
    return initOf Position(
        index,
        userAddress,
        poolAddress,
        tickLower,
        tickUpper,
        0,
    );
}

fun getLPAccountStateInit(userAddress: Address, poolAddress: Address): StateInit {
    return initOf LPAccount(
        userAddress,
        poolAddress,
        0,
        0
    );
}