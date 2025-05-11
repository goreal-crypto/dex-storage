import "../libraries/tick_bitmap";

message(0xa2db4430) FlipTick {
    tick: Int as int24;
}

contract TickBitmapTest {
    ticks: map<Int as int24, TickInfo>;
    receive() {}
    receive(msg: FlipTick) {
        self.ticks.set(msg.tick, emptyInfo())
    }
    init() {
        self.ticks.set(-200, emptyInfo());
        self.ticks.set(-55, emptyInfo());
        self.ticks.set(-4, emptyInfo());
        self.ticks.set(70, emptyInfo());
        self.ticks.set(78, emptyInfo());
        self.ticks.set(84, emptyInfo());
        self.ticks.set(139, emptyInfo());
        self.ticks.set(240, emptyInfo());
        self.ticks.set(535, emptyInfo());
    }
    get fun getNextInitializedTick(
        tick: Int,  
        zeroToOne: Bool, 
        tickSpacing: Int
    ): NextTick {
        return nextInitializedTick(tick, self.ticks, zeroToOne, tickSpacing);
    }
}

fun emptyInfo(): TickInfo {
    return TickInfo{
        liquidityGross: 0, 
        liquidityNet: 0, 
        feeGrowthOutside0X128: 0, 
        feeGrowthOutside1X128: 0
    } ;
}