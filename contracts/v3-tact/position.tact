import "./messages";

contract Position (
    index: Int as uint64,
    userAddress: Address,
    poolAddress: Address,
    tickLower: Int as int24,
    tickUpper: Int as int24,
    liquidity: Int as coins,
) {
    receive(msg: PositionInit) {
        throwUnless(WRONG_CALLER, self.liquidity == 0);
        self.liquidity = msg.liquidity;
    }
    receive(msg: PositionBurn) {
        throwUnless(WRONG_CALLER, sender() == self.poolAddress);
        self.liquidity -= msg.liquidity;
        throwUnless(INVALID_AMOUNT, self.liquidity >= 0);
        message(MessageParameters{
            to: self.poolAddress,
            value: 0,
            mode: SendRemainingBalance,
            bounce: false,
            body: PositionBurnNotification {
                queryId: msg.queryId,
                index: self.index,
                userAddress: self.userAddress,
                tickLower: self.tickLower,
                tickUpper: self.tickUpper,
                liquidity: msg.liquidity,
            }.toCell()
        });
    }
}