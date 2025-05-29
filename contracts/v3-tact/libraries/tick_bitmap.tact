struct NextTick {
    tick: Int as int24;
    initialized: Bool;
}

struct TickInfo {
    liquidityGross: Int as uint128;
    liquidityNet: Int as int128;
    feeGrowthOutside0X128: Int as uint256;
    feeGrowthOutside1X128: Int as uint256;
}

asm fun asmNextTick(key: Int, dict: map<Int as int24, TickInfo>, n: Int): Int? {
    DICTIGETNEXT
    IF:<{ 
        SWAP
        DROP
    }>ELSE<{
        PUSHNULL
    }>
}

asm fun asmPrevTick(key: Int, dict: map<Int as int24, TickInfo>, n: Int): Int? {
    DICTIGETPREVEQ
    IF:<{ 
        SWAP
        DROP
    }>ELSE<{
        PUSHNULL
    }>	
}

fun nextVirtualTick(tickCurrent: Int, tickSpacing: Int, zeroForOne: Bool): Int {
    let compressed = tickCurrent / tickSpacing - (
        (tickCurrent < 0 && tickCurrent % tickSpacing != 0) ? 1 : 0
    );    
    if (zeroForOne) {
        return (compressed - (compressed % 256)) * tickSpacing;
    } 
    return (compressed + 256 - ((compressed + 1) % 256)) * tickSpacing;
}

fun nextInitializedTick(
    tick: Int, 
    ticks: map<Int as int24, TickInfo>, 
    zeroToOne: Bool, 
    tickSpacing: Int
): NextTick {
    let nextTick = zeroToOne 
        ? asmPrevTick(tick, ticks, 24) 
        : asmNextTick(tick, ticks, 24);
    // dump(tick);

    let boundTick = nextVirtualTick(tick, tickSpacing, zeroToOne);
    // dump(tick);
    // dump(zeroToOne);
    // dump(boundTick);
    
    if (nextTick != null) {
        if (zeroToOne) {
            if (nextTick!! > boundTick) {
                return NextTick{
                    tick: nextTick!!,
                    initialized: true,
                };
            }
        } else {
            if (nextTick!! < boundTick) {
                return NextTick{
                    tick: nextTick!!,
                    initialized: true,
                };
            }
        }
    }
    return NextTick{
        tick: boundTick,
        initialized: false,
    }
}