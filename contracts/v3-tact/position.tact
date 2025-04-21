contract Position (
    userAddress: Address,
    poolAddress: Address,
    tickLower: Int as int24,
    tickUpper: Int as int24,
    liquidity: Int as coins,
) {
    receive(msg: PositionBurn) {
        message(MessageParameters{
            to: self.poolAddress,
            value: 0,
            mode: SendRemainingBalance,
            bounce: false,
            body: PositionBurnNotification {
                userAddress: self.userAddress,
                tickLower: self.tickLower,
                tickUpper: self.tickUpper,
                amount: self.liquidity,
            }.toCell()
        });
        self.liquidity = 0;
    }
}