import "./messages";

contract Position {
    index: Int as uint64;
    userAddress: Address;
    poolAddress: Address;
    tickLower: Int as int24;
    tickUpper: Int as int24;
    liquidity: Int as coins;
    feeGrowthInside0LastX128: Int as uint256;
    feeGrowthInside1LastX128: Int as uint256;

    init(
        index: Int,
        userAddress: Address,
        poolAddress: Address,
        tickLower: Int,
        tickUpper: Int,
        liquidity: Int,
        feeGrowthInside0X128: Int,
        feeGrowthInside1X128: Int
    ) {
        self.index = index;
        self.userAddress = userAddress;
        self.poolAddress = poolAddress;
        self.tickLower = tickLower;
        self.tickUpper = tickUpper;
        self.liquidity = liquidity;
        self.feeGrowthInside0LastX128 = feeGrowthInside0X128;
        self.feeGrowthInside1LastX128 = feeGrowthInside1X128;
    }
 
    receive(msg: PositionInit) {
        throwUnless(WRONG_CALLER, self.liquidity == 0);
        self.liquidity = msg.liquidity;
        self.feeGrowthInside0LastX128 = msg.feeGrowthInside0X128;
        self.feeGrowthInside1LastX128 = msg.feeGrowthInside1X128;
    }
    receive(msg: PositionBurn) {
        throwUnless(WRONG_CALLER, sender() == self.poolAddress);
        self.liquidity -= msg.liquidity;
        throwUnless(INVALID_AMOUNT, self.liquidity >= 0);
        let feeOwed0 = mulShiftRight(
            msg.feeGrowthInside0X128 - self.feeGrowthInside0LastX128,
            self.liquidity,
            128
        );
        let feeOwed1 = mulShiftRight(
            msg.feeGrowthInside1X128 - self.feeGrowthInside1LastX128,
            self.liquidity,
            128
        );
        self.feeGrowthInside0LastX128 = msg.feeGrowthInside0X128;
        self.feeGrowthInside1LastX128 = msg.feeGrowthInside1X128;
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
                feeOwed0: feeOwed0,
                feeOwed1: feeOwed1
            }.toCell()
        });
    }
}