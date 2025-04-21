message AddLiquidity {
    newAmount0: Int as coins;
    newAmount1: Int as coins;
    newEnough0: Int as coins;
    newEnough1: Int as coins;
    liquidity: Int as uint128;
    tickLower: Int as int24;
    tickUpper: Int as int24;
}


contract V3LPAccount {
    userAddress: Address;
    poolAddress: Address;
    amount0: Int as coins;
    amount1: Int as coins;
    // enough0: Int as coins;
    // enough1: Int as coins;

    receive(msg: AddLiquidity) {
        throwUnless(INVALID_CALLER, sender() == self.poolAddress);
        self.amount0 += msg.newAmount0;
        self.amount1 += msg.newAmount1;
        // self.enough0 = msg.newEnough0;
        // self.enough1 = msg.newEnough1;
        if (self.amount0 >= msg.newEnough0 && self.amount1 >= msg.newEnough1) {
            message(MessageParameters{
                to: self.poolAddress,
                value: 0,
                mode: SendRemainingValue,
                bounce: false,
                body: MintLiquidity {
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