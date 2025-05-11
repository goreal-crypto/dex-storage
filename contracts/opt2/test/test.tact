contract Test {
    map1: Cell;
    map2: map<Int as int256, Int as int256>;
    init() {
        self.map1 = createDict();
        self.map2 = emptyMap();
        self.map2.set(0, 100);
        self.map2.set(1, 200);
    }

    receive() {}
    get fun getNextTick(): Bool {
        // return self.mapp.get(tick);
        return nextTick(1, self.map2, 256) == null;
        
        // return 0;
    }
}


struct NextTick {
    flag: Bool;
    i: Int?;
    x: Slice?;
}

asm fun nextTick(key: Int, dict: map<Int as int256, Int as int256>, n: Int): Int? {
    DICTIGETNEXT
    IF:<{ 
        SWAP
        DROP
    }>ELSE<{
        PUSHNULL
    }>
}

asm fun createDict(): Cell {
    NEWDICT
}
