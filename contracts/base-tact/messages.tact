message(0xaaaaaaaa) AddLiquidity {
    queryId: Int;
    newAmount0: Int;
    newAmount1: Int;
    minLPOut: Int;
}

message CbAddLiquidity {
    queryId: Int;
    amount0: Int;
    amount1: Int;
    userAddress: Address;
    minLPOut: Int;
}

message RefundMe {
    queryId: Int;
}

message CbRefundMe {
    queryId: Int;
    amount0: Int;
    amount1: Int;
    userAddress: Address;
}

message DirectAddLiquidity {
    queryId: Int;
    amount0: Int;
    amount1: Int;
    minLPOut: Int;
}


message(0xaaaaffff) Swap {
    queryId: Int as uint64;
    fromAddress: Address;
    tokenWallet: Address;
    jettonAmount: Int as coins;
    minOutput: Int as coins;
    // hasRef: Bool;
    // refAddress: Address?;
}

message(0xabababab) ProvideLP {
    queryId: Int as uint64;
    fromUser: Address;
    minLPOut: Int as coins;
    amount0: Int as coins;
    amount1: Int as coins; 
}

message BurnNotification {
    query_id: Int;
    jetton_amount: Int;
    from_address: Address;
    response_address: Address;
}

message(0xffffaaaa) PayTo {
    queryId: Int as uint64;
    toAddress: Address;
    exitCode: Int as uint32;
    amount0Out: Int as coins;
    token0Address: Address;
    amount1Out: Int as coins;
    token1Address: Address;
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

message(0x7362d09c) JettonNotification {
    queryId: Int as uint64;
    amount: Int as coins;
    sender: Address;
    forwardPayload: Slice as remaining;
}

const MAX_COINS: Int = 100000;

const SWAP: Int = 0xafafafaf;
const PROVIDE_LP: Int = 0xfafafafa;
const SWAP_REFUND_RESERVE_ERR: Int = 0xcccccccc;
const SWAP_OK: Int = 0xcccccccd;

const INSUFFICIENT_GAS: Int = 1004;
const INVALID_CALLER: Int = 1005;
const INVALID_AMOUNT: Int = 1006;
const WRONG_CALLER: Int = 2003;
const SWAP_REFUND_NO_LIQ: Int = 2004;
const WRONG_OP: Int = 1001;
const ZERO_OUTPUT: Int = 1002;
const NO_LIQUIDITY: Int = 1003; 