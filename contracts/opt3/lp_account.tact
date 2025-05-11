import "./messages";

contract LPAccount (
    userAddress: Address,
    poolAddress: Address,
    amount0: Int as coins,
    amount1: Int as coins,
) {
    receive(msg: AddLiquidity) {
        throwUnless(INVALID_CALLER, sender() == self.poolAddress);
        self.amount0 += msg.newAmount0;
        self.amount1 += msg.newAmount1;
        if (self.amount0 >= msg.newEnough0 && self.amount1 >= msg.newEnough1) {
            message(MessageParameters{
                to: self.poolAddress,
                value: 0,
                mode: SendRemainingValue,
                bounce: false,
                body: MintLiquidity {
                    queryId: msg.queryId,
                    userAddress: self.userAddress,
                    amount0: self.amount0,
                    amount1: self.amount1,
                    liquidity: msg.liquidity,
                    tickLower: msg.tickLower,
                    tickUpper: msg.tickUpper,
                }.toCell()
            });
            self.amount0 = 0;
            self.amount1 = 0;
        }
    }
}