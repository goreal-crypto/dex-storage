import "../libraries/sqrt_price_math";

contract SqrtPriceMathTest {
    receive() {}
    get fun getAmount0Delta(sqrtRatioAX96: Int, sqrtRatioBX96: Int, liquidity: Int): Int {
        return amount0Delta(sqrtRatioAX96, sqrtRatioBX96, liquidity);
    }

    get fun getAmount1Delta(sqrtRatioAX96: Int, sqrtRatioBX96: Int, liquidity: Int): Int {
        return amount1Delta(sqrtRatioAX96, sqrtRatioBX96, liquidity);
    }

    get fun getAmount0Delta_(sqrtRatioAX96: Int, sqrtRatioBX96: Int, liquidity: Int, roundUp: Bool): Int {
        return amount0Delta_(sqrtRatioAX96, sqrtRatioBX96, liquidity, roundUp);
    }
    
    get fun getAmount1Delta_(sqrtRatioAX96: Int, sqrtRatioBX96: Int, liquidity: Int, roundUp: Bool): Int {
        return amount1Delta_(sqrtRatioAX96, sqrtRatioBX96, liquidity, roundUp);
    }

    get fun getNextSqrtPriceFromInput(
        sqrtPX96: Int,
        liquidity: Int,
        amountIn: Int,
        zeroForOne: Bool): Int {
            return nextSqrtPriceFromInput(sqrtPX96, liquidity, amountIn, zeroForOne);
    }

    get fun getNextSqrtPriceFromOutput(
        sqrtPX96: Int,
        liquidity: Int,
        amountOut: Int,
        zeroForOne: Bool): Int {
            return nextSqrtPriceFromOutput(sqrtPX96, liquidity, amountOut, zeroForOne);
    }

}