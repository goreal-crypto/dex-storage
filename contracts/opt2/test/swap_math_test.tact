import "../libraries/swap_math";

contract SwapMathTest {
    receive() {}
    get fun getComputeSwapStep(
        sqrtRatioCurrentX96: Int,
        sqrtRatioTargetX96: Int,
        liquidity: Int,
        amountRemaining: Int,
        feePips: Int
    ): SwapStep {
        return computeSwapStep(sqrtRatioCurrentX96, sqrtRatioTargetX96, liquidity, amountRemaining, feePips);
    }
}