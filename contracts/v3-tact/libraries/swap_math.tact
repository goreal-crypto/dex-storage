import "./sqrt_price_math";

struct SwapStep {
    sqrtRatioNextX96: Int as uint160;
    amountIn: Int as uint256;
    amountOut: Int as uint256;
    // feeAmount: Int as uint256;  
}

fun computeSwapStep(
    sqrtRatioCurrentX96: Int,
    sqrtRatioTargetX96: Int,
    liquidity: Int,
    amountRemaining: Int,
    // feePips: Int
): SwapStep {
    let zeroForOne = sqrtRatioCurrentX96 >= sqrtRatioTargetX96;
    let exactIn = amountRemaining >= 0;
    let amountIn = 0;
    let sqrtRatioNextX96 = 0;
    if (exactIn) {
        let amountRemainingLessFee = amountRemaining;
        amountIn = zeroForOne 
            ? amount0Delta_(sqrtRatioTargetX96, sqrtRatioCurrentX96, liquidity, true)
            : amount1Delta_(sqrtRatioTargetX96, sqrtRatioCurrentX96, liquidity, true);
        if (amountRemainingLessFee >= amountIn) {
            sqrtRatioNextX96 = sqrtRatioTargetX96;
        } else {
            // TODO
        }

    }
}