message(0x20ad5e4) PositionBurn {

}

message PositionBurnNotification {
    index: Int as uint64;
    userAddress: Address;
    tickLower: Int as int24;
    tickUpper: Int as int24;
    amount: Int as coins;
}

message PositionInit {
    tickLower: Int as int24;
    tickUpper: Int as int24;
    liquidity: Int as coins;
}


contract Position (
    index: Int as uint64,
    userAddress: Address,
    poolAddress: Address,
    tickLower: Int as int24,
    tickUpper: Int as int24,
    liquidity: Int as coins,
) {
    receive(msg: PositionInit) {
        // from pool
        self.tickLower = msg.tickLower;
        self.tickUpper = msg.tickUpper;
        self.liquidity = msg.liquidity;
    }
    receive(msg: PositionBurn) {
        message(MessageParameters{
            to: self.poolAddress,
            value: 0,
            mode: SendRemainingBalance,
            bounce: false,
            body: PositionBurnNotification {
                index: self.index,
                userAddress: self.userAddress,
                tickLower: self.tickLower,
                tickUpper: self.tickUpper,
                amount: self.liquidity,
            }.toCell()
        });
        self.liquidity = 0;
    }
}