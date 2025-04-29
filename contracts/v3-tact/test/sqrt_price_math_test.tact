import "../libraries/sqrt_price_math";

contract SqrtPriceMathTest {
    receive() {}
    get fun getAmount0Delta(sqrtRatioAX96: Int, sqrtRatioBX96: Int, liquidity: Int): Int {
        return amount0Delta(sqrtRatioAX96, sqrtRatioBX96, liquidity);
    }

    get fun getAmount1Delta(sqrtRatioAX96: Int, sqrtRatioBX96: Int, liquidity: Int): Int {
        return amount1Delta(sqrtRatioAX96, sqrtRatioBX96, liquidity);
    }
}