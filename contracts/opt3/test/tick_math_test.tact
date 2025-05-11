import "../libraries/tick_math";

contract TickMathTest {
    receive() {}
    get fun getSqrtRatioAtTick(tick: Int): Int {
        return sqrtRatioAtTick(tick);
    }

    get fun getTickAtSqrtRatio(sqrtPriceX96: Int): Int {
        return tickAtSqrtRatio(sqrtPriceX96);
    }
}