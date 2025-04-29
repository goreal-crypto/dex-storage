import "./sqrt_price_math";

struct SwapStep {
    sqrtRatioNextX96: Int as uint160;
    amountIn: Int as uint256;
    amountOut: Int as uint256;
    feeAmount: Int as uint256;  
}

fun computeSwapStep(
    sqrtRatioCurrentX96: Int,
    sqrtRatioTargetX96: Int,
    liquidity: Int,
    amountRemaining: Int,
    feePips: Int
): SwapStep {
    let zeroForOne = sqrtRatioCurrentX96 >= sqrtRatioTargetX96;
    let exactIn = amountRemaining >= 0;
    let amountIn = 0;
    let amountOut = 0;
    let sqrtRatioNextX96 = 0;
    let feeAmount = 0;
    if (exactIn) {
        let amountRemainingLessFee = muldiv(amountRemaining, 1000000 - feePips, 1000000);
        dump("hello");
        dump(zeroForOne);
        amountIn = zeroForOne 
            ? amount0Delta_(sqrtRatioTargetX96, sqrtRatioCurrentX96, liquidity, true)
            : amount1Delta_(sqrtRatioCurrentX96, sqrtRatioTargetX96, liquidity, true);
        dump(amountIn);
        dump("hello2");


        if (amountRemainingLessFee >= amountIn) {
            sqrtRatioNextX96 = sqrtRatioTargetX96;
        } else {
            sqrtRatioNextX96 = nextSqrtPriceFromOutput(
                sqrtRatioCurrentX96,
                liquidity,
                amountRemainingLessFee,
                zeroForOne
            );
        }
    } else {
        amountOut = zeroForOne
            ? amount1Delta_(sqrtRatioTargetX96, sqrtRatioCurrentX96, liquidity, false)
            : amount0Delta_(sqrtRatioCurrentX96, sqrtRatioTargetX96, liquidity, false);
        if (-amountRemaining >= amountOut) {
            sqrtRatioNextX96 = sqrtRatioTargetX96;
        } else {
            sqrtRatioNextX96 = nextSqrtPriceFromOutput(
                sqrtRatioCurrentX96,
                liquidity,
                -amountRemaining,
                zeroForOne
            );
        }
    }

    let max = sqrtRatioTargetX96 == sqrtRatioNextX96;

    if (zeroForOne) {
        amountIn = max && exactIn
            ? amountIn
            : amount0Delta_(sqrtRatioNextX96, sqrtRatioCurrentX96, liquidity, true);
        amountOut = max && !exactIn
            ? amountOut
            : amount1Delta_(sqrtRatioNextX96, sqrtRatioCurrentX96, liquidity, false);
    } else {
        amountIn = max && exactIn
            ? amountIn
            : amount1Delta_(sqrtRatioCurrentX96, sqrtRatioNextX96, liquidity, true);
        amountOut = max && !exactIn
            ? amountOut
            : amount0Delta_(sqrtRatioCurrentX96, sqrtRatioNextX96, liquidity, false);
    }
    dump(zeroForOne);
    dump(max);
    dump(exactIn);
    dump(amountIn);
    dump(amount0Delta_(sqrtRatioNextX96, sqrtRatioCurrentX96, liquidity, true));
    dump(amount1Delta_(sqrtRatioCurrentX96, sqrtRatioNextX96, liquidity, true));

    if (!exactIn && (amountOut > -amountRemaining)) {
        amountOut = -amountRemaining;
    }
    if (exactIn && (sqrtRatioNextX96 != sqrtRatioTargetX96)) {
        feeAmount = amountRemaining - amountIn;
    } else {
        feeAmount = muldivc(amountIn, feePips, 1000000 - feePips);
    }
    return SwapStep{
        sqrtRatioNextX96: sqrtRatioNextX96,
        amountIn: amountIn,
        amountOut: amountOut,
        feeAmount: feeAmount,
    };
}