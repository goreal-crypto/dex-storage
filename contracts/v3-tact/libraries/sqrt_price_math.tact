fun amount0Delta(sqrtRatioAX96: Int, sqrtRatioBX96: Int, liquidity: Int): Int {
    return 
        liquidity < 0
        ? -amount0Delta_(sqrtRatioAX96, sqrtRatioBX96, -liquidity, false)
        : amount0Delta_(sqrtRatioAX96, sqrtRatioBX96, liquidity, true);
}

fun amount0Delta_(sqrtRatioAX96: Int, sqrtRatioBX96: Int, liquidity: Int, roundUp: Bool): Int {
    if (sqrtRatioAX96 > sqrtRatioBX96) {
        let tmp = sqrtRatioAX96;
        sqrtRatioAX96 = sqrtRatioBX96;
        sqrtRatioBX96 = tmp;
    }
    let numerator1 = liquidity << 96;
    let numerator2 = sqrtRatioBX96 - sqrtRatioAX96;

    return 
        roundUp
        ? divc(muldivc(numerator1, numerator2, sqrtRatioBX96), sqrtRatioAX96)
        : muldiv(numerator1, numerator2, sqrtRatioBX96) / sqrtRatioAX96;
}

fun amount1Delta(sqrtRatioAX96: Int, sqrtRatioBX96: Int, liquidity: Int): Int {
    return 
        liquidity < 0
        ? -amount1Delta_(sqrtRatioAX96, sqrtRatioBX96, -liquidity, false)
        : amount1Delta_(sqrtRatioAX96, sqrtRatioBX96, liquidity, true);
}

fun amount1Delta_(sqrtRatioAX96: Int, sqrtRatioBX96: Int, liquidity: Int, roundUp: Bool): Int {
    if (sqrtRatioAX96 > sqrtRatioBX96) {
        let tmp = sqrtRatioAX96;
        sqrtRatioAX96 = sqrtRatioBX96;
        sqrtRatioBX96 = tmp;
    }

    return 
        roundUp
        ? mulShiftRightCeil(liquidity, sqrtRatioBX96 - sqrtRatioAX96, 96)
        : mulShiftRight(liquidity, sqrtRatioBX96 - sqrtRatioAX96, 96);
}

asm fun muldiv(x: Int, y: Int, z: Int): Int { MULDIV}