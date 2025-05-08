fun amount0Delta(
    sqrtRatioAX96: Int, 
    sqrtRatioBX96: Int, 
    liquidity: Int
): Int {
    return 
        liquidity < 0
        ? -amount0Delta_(sqrtRatioAX96, sqrtRatioBX96, -liquidity, false)
        : amount0Delta_(sqrtRatioAX96, sqrtRatioBX96, liquidity, true);
}

fun amount0Delta_(
    sqrtRatioAX96: Int, 
    sqrtRatioBX96: Int, 
    liquidity: Int, 
    roundUp: Bool
): Int {
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

fun amount1Delta(
    sqrtRatioAX96: Int, 
    sqrtRatioBX96: Int, 
    liquidity: Int
): Int {
    return 
        liquidity < 0
        ? -amount1Delta_(sqrtRatioAX96, sqrtRatioBX96, -liquidity, false)
        : amount1Delta_(sqrtRatioAX96, sqrtRatioBX96, liquidity, true);
}

fun amount1Delta_(
    sqrtRatioAX96: Int, 
    sqrtRatioBX96: Int, 
    liquidity: Int, 
    roundUp: Bool
): Int {
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

fun nextSqrtPriceFromAmount0RoundingUp(
    sqrtPX96: Int,
    liquidity: Int,
    amount: Int,
    add: Bool
): Int {
    if (amount == 0) {
        return sqrtPX96;
    }
    let numerator1 = liquidity << 96;
    if (add) {
        let product = amount * sqrtPX96; // check for overflow, but tvm throws 4
        if (product / amount == sqrtPX96) {
            let denominator = numerator1 + product;
            if (denominator >= numerator1) {
                return muldivc(numerator1, sqrtPX96, denominator);
            }
        }
        return divc(numerator1, numerator1 / sqrtPX96 + amount);
    } else {
        let product = amount * sqrtPX96;
        // require((product = amount * sqrtPX96) / amount == sqrtPX96 && numerator1 > product);
        let denominator = numerator1 - product;
        return muldivc(numerator1, sqrtPX96, denominator);
    }
}

fun nextSqrtPriceFromAmount1RoundingDown(
    sqrtPX96: Int,
    liquidity: Int,
    amount: Int,
    add: Bool
): Int {
    if (add) {
        let quotient = (
            amount <= (1 << 160 - 1)
            ? (amount << 96) / liquidity
            : muldiv(amount, 0x1000000000000000000000000, liquidity)
        );
        return sqrtPX96 + quotient;
    } else {
        let quotient = (
            amount <= (1 << 160 - 1)
            ? divc(amount << 96, liquidity)
            : muldivc(amount, 0x1000000000000000000000000, liquidity)
        );
        // require(sqrtPX96 > quotient);
        return sqrtPX96 - quotient;  
    }
}

fun nextSqrtPriceFromInput(
    sqrtPX96: Int,
    liquidity: Int,
    amountIn: Int,
    zeroForOne: Bool
): Int {
    return zeroForOne   
        ? nextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountIn, true)
        : nextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountIn, true);
}

fun nextSqrtPriceFromOutput(
    sqrtPX96: Int,
    liquidity: Int,
    amountOut: Int,
    zeroForOne: Bool
): Int {
    return zeroForOne   
        ? nextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountOut, false)
        : nextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountOut, false);
}

asm fun muldiv(x: Int, y: Int, z: Int): Int { MULDIV}