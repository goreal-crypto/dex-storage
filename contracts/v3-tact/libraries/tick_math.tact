fun sqrtRatioAtTick(tick: Int): Int {
    let absTick = abs(tick);
    let ratio = (absTick & 0x1) != 0 ? 0xfffcb933bd6fad37aa2d162d1a594001 : 0x100000000000000000000000000000000;
    if ((absTick & 0x2) != 0) {
        ratio = (ratio * 0xfff97272373d413259a46990580e213a) >> 128;
    }
    if ((absTick & 0x4) != 0) { 
        ratio = (ratio * 0xfff2e50f5f656932ef12357cf3c7fdcc) >> 128;
    }
    if ((absTick & 0x8) != 0) { 
        ratio = (ratio * 0xffe5caca7e10e4e61c3624eaa0941cd0) >> 128;
    }
    if ((absTick & 0x10) != 0) {
            ratio = (ratio * 0xffcb9843d60f6159c9db58835c926644) >> 128;
    }
    if ((absTick & 0x20) != 0) { 
        ratio = (ratio * 0xff973b41fa98c081472e6896dfb254c0) >> 128;
    }
    if ((absTick & 0x40) != 0) {
        ratio = (ratio * 0xff2ea16466c96a3843ec78b326b52861) >> 128;
    }
    if ((absTick & 0x80) != 0) { 
        ratio = (ratio * 0xfe5dee046a99a2a811c461f1969c3053) >> 128;
    }
    if ((absTick & 0x100) != 0) {
        ratio = (ratio * 0xfcbe86c7900a88aedcffc83b479aa3a4) >> 128;
    }
    if ((absTick & 0x200) != 0) {
        ratio = (ratio * 0xf987a7253ac413176f2b074cf7815e54) >> 128;
    }
    if ((absTick & 0x400) != 0) {
        ratio = (ratio * 0xf3392b0822b70005940c7a398e4b70f3) >> 128;
    }
    if ((absTick & 0x800) != 0)  {
        ratio = (ratio * 0xe7159475a2c29b7443b29c7fa6e889d9) >> 128;
    }
    if ((absTick & 0x1000) != 0) {
        ratio = (ratio * 0xd097f3bdfd2022b8845ad8f792aa5825) >> 128;
    }
    if ((absTick & 0x2000) != 0) {
        ratio = (ratio * 0xa9f746462d870fdf8a65dc1f90e061e5) >> 128;
    }
    if ((absTick & 0x4000) != 0) {
        ratio = (ratio * 0x70d869a156d2a1b890bb3df62baf32f7) >> 128;
    }
    if ((absTick & 0x8000) != 0) {
        ratio = (ratio * 0x31be135f97d08fd981231505542fcfa6) >> 128;
    }
    if ((absTick & 0x10000) != 0) {
        ratio = (ratio * 0x9aa508b5b7a84e1c677de54f3e99bc9) >> 128;
    }
    if ((absTick & 0x20000) != 0) {
        ratio = (ratio * 0x5d6af8dedb81196699c329225ee604) >> 128;
    }
    if ((absTick & 0x40000) != 0) {
        ratio = (ratio * 0x2216e584f5fa1ea926041bedfe98) >> 128;
    }
    if ((absTick & 0x80000) != 0) {
        ratio = (ratio * 0x48a170391f7dc42444e8fa2) >> 128;
    }
    if (tick > 0) {
        ratio = 115792089237316195423570985008687907853269984665640564039457584007913129639935 / ratio;
    }
    return (ratio >> 32) + (ratio % (1 << 32) == 0 ? 0 : 1);
}


fun tickAtSqrtRatio(sqrtPriceX96: Int): Int {
    let ratio = sqrtPriceX96 << 32;
    let r = ratio;
    let msb = 0;

    if (r > 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF) {
        r = r >> 128;
        msb |= (1 << 7);
    }
    if (r > 0xFFFFFFFFFFFFFFFF) {
        r = r >> 64;
        msb |= (1 << 6);
    }
    if (r > 0xFFFFFFFF) {
        r = r >> 32;
        msb |= (1 << 5);
    }
    if (r > 0xFFFF) {
        r = r >> 16;
        msb |= (1 << 4);
    }
    if (r > 0xFF) {
        r = r >> 8;
        msb |= (1 << 3);
    }
    if (r > 0xF) {
        r = r >> 4;
        msb |= (1 << 2);
    }
    if (r > 0x3) {
        r = r >> 2;
        msb |= (1 << 1);
    }
    if (r > 0x1) {
        msb |= 1;
    }

    if (msb >= 128) {
        r = ratio >> (msb - 127);
    } else {
        r = ratio << (127 - msb);
    }

    let log_2 = (msb - 128) << 64;
    let i = 0;
    while (i < 14) {
        r = (r * r) >> 127;
        let f = (r >> 128) & 1;
        log_2 |= f << (63 - i);
        if (f == 1) {
            r >>= 1;
        }
        i += 1;
    }

    let log_sqrt10001 = log_2 * 255738958999603826347141;

    let tickLow = (log_sqrt10001 - 3402992956809132418596140100660247210) >> 128;
    let tickHi = (log_sqrt10001 + 291339464771989622907027621153398088495) >> 128;

    return sqrtRatioAtTick(tickHi) <= sqrtPriceX96 ? tickHi : tickLow;
}