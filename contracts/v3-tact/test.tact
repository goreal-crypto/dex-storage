import "./libraries/sqrt_price_math";
import "./libraries/tick_math";

contract Test {
    receive() {}
    
    get fun getSqrtPriceAtTick(tick: Int): Int {
        return sqrtRatioAtTick(tick)
    }

    get fun getTickAtSqrtRatio(sqrtPriceX96: Int): Int {
        return tickAtSqrtRatio(sqrtPriceX96);
    }

    get fun getAmount0Delta(sqrtRatioAX96: Int, sqrtRatioBX96: Int, liquidity: Int): Int {
        return amount0Delta(sqrtRatioAX96, sqrtRatioBX96, liquidity);
    }
    
    get fun getAmount1Delta(sqrtRatioAX96: Int, sqrtRatioBX96: Int, liquidity: Int): Int {
        return amount1Delta(sqrtRatioAX96, sqrtRatioBX96, liquidity);
    }
}