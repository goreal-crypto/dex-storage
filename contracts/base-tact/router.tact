import "./pool";

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

const swap: Int = 0xafafafaf;
const provide_lp: Int = 0xfafafafa;




// struct SwapPayload {
//     a: Int as uint32;
//     b: Address;
//     toAddress: Address;
//     minOutput: Int as coins;
//     // hasRef: Bool;
//     // refAddress: Address?;
// }

const INSUFFICIENT_GAS: Int = 1004;
const INVALID_CALLER: Int = 1005;
const INVALID_AMOUNT: Int = 1006;


// TODO
inline fun getPoolStateInit(token0Address: Address, token1Address: Address): StateInit {
    return initOf Pool(
        myAddress(), // routerAddress
        // 0,           // lp_fee
        // 0,           // ref_fee
        token0Address, // token0Address
        token1Address // token1Address
        // 0,           // total_supply_lp
        // 0,           // collected_token0_protocol_fee
        // 0,           // collected_token1_protocol_fee
        // ?,           // protocol_fee_address
        // 0,           // reserve0
        // 0,           // reserve1
    );
}

inline fun getPoolAddress(token0Address: Address, token1Address: Address): Address {
    return contractAddress(getPoolStateInit(token0Address, token1Address));
}


contract Router {
    // isLocked: Bool;
    // admin_address: Address;
    // jetton_lp_wallet_code: Cell; 
    // pool_code: Cell;
    // lp_account_code: Cell; 
    // temp_upgrade: Cell;
    receive(){}

    receive(msg: PayTo) {
        // let gasRequired = get_gas_fee(20000, WORKCHAIN); // TODO
        let msgValue = context().value;
        // throwUnless(INSUFFICIENT_GAS, msgValue > gasRequired);
        let poolAddress = getPoolAddress(msg.token0Address, msg.token1Address);
        throwUnless(INVALID_CALLER, poolAddress == sender());

        let tonAmount = 0;
        let messageMode = SendRemainingValue;
        if ((msg.amount0Out > 0) && (msg.amount1Out > 0)) {
            // tonAmount = (msgValue - gasRequired) / 2;
            tonAmount = msgValue / 2;
            messageMode = SendDefaultMode;
        }
        if (msg.amount0Out > 0) {
            message(MessageParameters{
                to: msg.token0Address,
                value: tonAmount,
                mode: messageMode,
                bounce: false, // ?
                body: JettonTransfer {
                    queryId: msg.queryId,
                    amount: msg.amount0Out,
                    destination: msg.toAddress,
                    responseDestination: msg.toAddress,
                    customPayload: null, // .store_uint(0, 1);
                    forwardTonAmount: 0,
                    forwardPayload: emptySlice(), // .store_uint(0, 1);
                }.toCell()
            });
        }
        if (msg.amount1Out > 0) {
            message(MessageParameters{
                to: msg.token1Address,
                value: tonAmount,
                mode: messageMode,
                bounce: false, // ?
                body: JettonTransfer {
                    queryId: msg.queryId,
                    amount: msg.amount1Out,
                    destination: msg.toAddress,
                    responseDestination: msg.toAddress,
                    customPayload: null, // .store_uint(0, 1);
                    forwardTonAmount: 0,
                    forwardPayload: emptySlice(), // .store_uint(0, 1);
                }.toCell()
            });
        }
    }

    receive(msg: JettonNotification) {
        throwUnless(INVALID_AMOUNT, msg.amount > 0);
        let payload: Slice = msg.forwardPayload;
        let opcode: Int = payload.loadUint(32);
        let token1Address: Address = payload.loadAddress();
        let ctx: Context = context();
        let fwdFee = ctx.readForwardFee();
        if ((fwdFee * 6 > ctx.value) || token1Address == ctx.sender) { // || self.isLocked) {
            // let exitCode: Slice as remaining = "";
            // if (self.isLocked) {
            //     exitCode = transfer_bounce_locked;
            // } else {
            //     exitCode = transfer_bounce_invalid_request;
            // }
            message(MessageParameters{
                to: ctx.sender,
                value: 0,
                mode: SendRemainingValue,
                bounce: false,
                body: JettonTransfer {
                    queryId: msg.queryId,
                    amount: msg.amount,
                    destination: ctx.sender,
                    responseDestination: ctx.sender,
                    customPayload: null, // .store_uint(0, 1);
                    forwardTonAmount: 0,
                    forwardPayload: emptySlice(), // .store_uint(0, 1);
                }.toCell()
            });
        } else {
            if (opcode == swap) {
                let toAddress = payload.loadAddress();
                let minOutput = payload.loadCoins();   
                // let swapPayload: SwapPayload = SwapPayload.fromSlice(msg.forwardPayload);
                // if (swapPayload.hasRef) {
                //     swapPayload.refAddress = msg.sender;
                // }

                let poolAddress: Address = getPoolAddress(ctx.sender, token1Address);
                message(MessageParameters{
                    to: poolAddress,
                    value: 0,
                    mode: SendRemainingValue,
                    bounce: false,
                    body: Swap {
                        queryId: msg.queryId,
                        fromAddress: toAddress, // swapPayload.toAddress,
                        tokenWallet: ctx.sender,
                        jettonAmount: msg.amount,
                        minOutput: minOutput, // swapPayload.minOutput,
                        // hasRef: swapPayload.hasRef,
                        // refAddress: msg.sender
                    }.toCell()
                });
            } else if (opcode == provide_lp) {
                // let transferredMsg: ProvideLP = ProvideLP.fromSlice(payload);
                let minLPOut: Int = payload.loadCoins();
                let poolAddress: Address = getPoolAddress(ctx.sender, token1Address);
                message(MessageParameters{
                    to: poolAddress,
                    value: 0,
                    mode: SendRemainingValue,
                    bounce: false,
                    body: ProvideLP {
                        queryId: msg.queryId,
                        fromAddress: msg.sender,
                        minLPOut: minLPOut,
                        amount0: msg.amount, // 0
                        amount1: 0 // msg.amount
                    }.toCell()
                });    
            }
        }
    }  

    get fun getPoolAddress(token0Address: Address, token1Address: Address): Address {
        return getPoolAddress(token0Address, token1Address)
    }
}

