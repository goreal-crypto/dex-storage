message(0xaaaaaaa1) AddLiquidity {
    queryId: Int;
    newAmount0: Int;
    newAmount1: Int;
    minLPOut: Int;
}

message(0xaaaaaaa2) CbAddLiquidity {
    queryId: Int;
    amount0: Int;
    amount1: Int;
    userAddress: Address;
    minLPOut: Int;
}

message(0xaaaaaaa3) RefundMe {
    queryId: Int;
}

message(0xaaaaaaa4) CbRefundMe {
    queryId: Int;
    amount0: Int;
    amount1: Int;
    userAddress: Address;
}

message(0xaaaaaaa5) DirectAddLiquidity {
    queryId: Int;
    amount0: Int;
    amount1: Int;
    minLPOut: Int;
}

message(0xaaaaaaa6) Swap {
    queryId: Int as uint64;
    fromAddress: Address;
    tokenWallet: Address;
    jettonAmount: Int as coins;
    minOutput: Int as coins;
    // hasRef: Bool;
    // refAddress: Address?;
}

message(0xaaaaaaa7) ProvideLP {
    queryId: Int as uint64;
    fromUser: Address;
    minLPOut: Int as coins;
    amount0: Int as coins;
    amount1: Int as coins; 
}

message(0xaaaaaaa8) PayTo {
    queryId: Int as uint64;
    toAddress: Address;
    exitCode: Int as uint32;
    amount0Out: Int as coins;
    token0Address: Address;
    amount1Out: Int as coins;
    token1Address: Address;
}

message(0xaaaaaaa9) SetFees {
    newLpFee: Int as uint8;
    newProtocolFee: Int as uint8;
    newRefFee: Int as uint8;
    newProtocolFeeAddress: Address;
}


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

const MAX_COINS: Int = 1329227995784915872903807060280344575;
const REQUIRED_MIN_LIQUIDITY: Int = 1000;
const FEE_DIVIDER: Int = 10000;

const SWAP: Int = 0xfffffffa;
const PROVIDE_LP: Int = 0xfffffffb;
const SWAP_REFUND_RESERVE_ERR: Int = 0xfffffffc;
const SWAP_OK: Int = 0xfffffffd;
const REFUND_OK: Int = 0xfffffffe;

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