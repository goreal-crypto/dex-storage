fun computeSwapStep(
    zeroForOne: Bool,
    sqrtPriceCurrent: Int,
    sqrtPriceTarget: Int,
    liquidity: Int,
    amountRemaining: Int,
    exactIn: Bool
): (Int, Int, Int) {
    if (zeroForOne) {
        let amountIn = amount0Delta(sqrtPriceTarget, sqrtPriceCurrent, liquidity);
        if (amountIn > amountRemaining) {
            let newPrice = getNewSqrtPriceFromInput(sqrtPriceCurrent, liquidity, amountRemaining, true);
            let amountOut = amount1Delta(newPrice, sqrtPriceCurrent, liquidity);
            return (newPrice, amountRemaining, amountOut);
        } else {
            let amountOut = amount1Delta(sqrtPriceTarget, sqrtPriceCurrent, liquidity);
            return (sqrtPriceTarget, amountIn, amountOut);
        }
    } else {
        let amountIn = amount1Delta(sqrtPriceCurrent, sqrtPriceTarget, liquidity);
        if (amountIn > amountRemaining) {
            let newPrice = getNewSqrtPriceFromInput(sqrtPriceCurrent, liquidity, amountRemaining, false);
            let amountOut = amount0Delta(sqrtPriceCurrent, newPrice, liquidity);
            return (newPrice, amountRemaining, amountOut);
        } else {
            let amountOut = amount0Delta(sqrtPriceCurrent, sqrtPriceTarget, liquidity);
            return (sqrtPriceTarget, amountIn, amountOut);
        }
    }
}