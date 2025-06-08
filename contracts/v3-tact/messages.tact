message(1) AddLiquidity {
    queryId: Int as uint64;
    newAmount0: Int as coins;
    newAmount1: Int as coins;
    newEnough0: Int as coins;
    newEnough1: Int as coins;
    liquidity: Int as uint128;
    tickLower: Int as int24;
    tickUpper: Int as int24;
}

message(2) MintLiquidity {
    queryId: Int as uint64;
    userAddress: Address;
    amount0: Int as coins;
    amount1: Int as coins;
    liquidity: Int as uint128;
    tickLower: Int as int24;
    tickUpper: Int as int24;
}


message(4) Swap {
    queryId: Int as uint64;
    userAddress: Address;
    zeroForOne: Bool;
    amountSpecified: Int as int256;
    sqrtPriceLimitX96: Int as uint160;
}

message(5) Initialize {
    queryId: Int as uint64;
    sqrtPriceX96: Int as uint160;
}

message(6) ProvideLiquidity {
    queryId: Int as uint64;
    userAddress: Address;
    amount0: Int as coins;
    amount1: Int as coins;
    enough0: Int as coins;
    enough1: Int as coins;
    liquidity: Int as uint128;
    tickLower: Int as int24;
    tickUpper: Int as int24;
}

message(7) PayTo {
    queryId: Int as uint64;
    toAddress: Address;
    amount0Out: Int as coins;
    token0Address: Address;
    amount1Out: Int as coins;
    token1Address: Address;
}

message(8) PositionBurn {
    queryId: Int as uint64;
    liquidity: Int as coins;
    feeGrowthInside0X128: Int as uint256;
    feeGrowthInside1X128: Int as uint256;
}

message(9) StartBurn {
    queryId: Int as uint64;
    index: Int as uint64;
    tickLower: Int as int24;
    tickUpper: Int as int24;
    liquidity: Int as coins;
}

message(10) PositionBurnNotification {
    queryId: Int as uint64;
    index: Int as uint64;
    userAddress: Address;
    tickLower: Int as int24;
    tickUpper: Int as int24;
    liquidity: Int as coins;
    feeOwed0: Int as uint128;
    feeOwed1: Int as uint128;
}

message(11) PositionInit {
    queryId: Int as uint64;
    liquidity: Int as coins;
    feeGrowthInside0X128: Int as uint256;
    feeGrowthInside1X128: Int as uint256;
}

message(12) PoolInitialize {
    queryId: Int as uint64;
    token0Address: Address;
    token1Address: Address;
    sqrtPriceX96: Int as uint160;
}

// ============================================================
// Jetton messages

message(0xf8a7ea5) JettonTransfer {
    queryId: Int as uint64;
    amount: Int as coins;
    destination: Address;
    responseDestination: Address?;
    customPayload: Cell?;
    forwardTonAmount: Int as coins;
    forwardPayload: Slice as remaining;
}

message(0x178d4519) JettonTransferInternal {
    queryId: Int as uint64;
    amount: Int as coins;
    sender: Address;
    responseDestination: Address?;
    forwardTonAmount: Int as coins;
    forwardPayload: Slice as remaining;
}

message(0x7362d09c) JettonNotification {
    queryId: Int as uint64;
    amount: Int as coins;
    sender: Address;
    forwardPayload: Slice as remaining;
}

message(0x595f07bc) JettonBurn {
    queryId: Int as uint64;
    amount: Int as coins;
    responseDestination: Address?;
    customPayload: Cell?;
}

message(0x7bdd97de) JettonBurnNotification {
    queryId: Int as uint64;
    amount: Int as coins;
    sender: Address;
    responseDestination: Address?;
}

message(0xd53276db) JettonExcesses {
    queryId: Int as uint64;
}

struct JettonWalletData {
    balance: Int;
    owner: Address;
    minter: Address;
    code: Cell;
}

message(0x2c76b973) ProvideWalletAddress {
    queryId: Int as uint64;
    ownerAddress: Address;
    includeAddress: Bool;
}

// ============================================================

const WORKCHAIN: Int = 0;
const MAX_COINS: Int = 1329227995784915872903807060280344575;
const REQUIRED_MIN_LIQUIDITY: Int = 1000;
const FEE_DIVIDER: Int = 10000;
const HOLE_ADDRESS: Address = address("EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c");
const MIN_FEE: Int = 0;
const MAX_FEE: Int = 100;
const REQUIRED_TON_RESERVE: Int = 10000000;
const MIN_TICK: Int = -887272;
const MAX_TICK: Int = 887272;


const SWAP: Int = 0xfffffff1;
const PROVIDE_LP: Int = 0xfffffff2;
const SWAP_REFUND_RESERVE_ERR: Int = 0xfffffff3;
const SWAP_OK: Int = 0xfffffff4;
const REFUND_OK: Int = 0xfffffff5;
const SWAP_OK_REF: Int = 0xfffffff6;
const BURN_OK: Int = 0xfffffff7;


const WRONG_OP: Int = 1001;
const ZERO_OUTPUT: Int = 1002;
const NO_LIQUIDITY: Int = 1003; 
const INSUFFICIENT_GAS: Int = 1004;
const INVALID_CALLER: Int = 1005;
const INVALID_AMOUNT: Int = 1006;
const WRONG_CALLER: Int = 1007;
const SWAP_REFUND_NO_LIQ: Int = 1008;
const LOW_LIQUIDITY: Int = 1009;
const REQUIRED_MIN_COLLECT_FEES: Int = 1010;
const FEE_OUT_OF_RANGE: Int = 1011;
const INVALID_RECIPIENT: Int = 1012;
const INVALID_TOKEN: Int = 1013;