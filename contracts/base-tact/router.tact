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

message(0xaaaaffff) Swap {
    token1Address: Address;
    expectedOutput: Int as coins;
    toAddress: Address;
    ref: Bool;
    refAddress: Address?;
}

const INSUFFICIENT_GAS: Int = 1004;
const INVALID_CALLER: Int = 1005;
const INVALID_AMOUNT: Int = 1006;


// TODO
inline fun getPoolStateInit(token0Address: Address, token1Address: Address): StateInit {
    return initOf Pool(
        // myAddress(), // router_address
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
    // is_locked: Bool;
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

    // receive(msg: JettonNotification) {
    //     throwUnless(INVALID_AMOUNT, msg.amount > 0);
    //     let payload: Slice = msg.forwardPayload;
    //     let opcode = payload.loadUint(32);
    //     let token1Address = payload.loadAddress()
    //     let ctx = context();
    //     let fwdFee = ctx.readForwardFee();
    //     if ((fwdFee * 6 > ctx.value) || token1Address == ctx.sender || self.isLocked) {
    //         let exitCode: Slice as remaining = "";
    //         if (self.isLocked) {
    //             exitCode = transfer_bounce_locked;
    //         } else {
    //             exitCode = transfer_bounce_invalid_request;
    //         }
    //         message(MessageParameters{
    //             to: ctx.sender,
    //             value: 0,
    //             mode: SendRemainingValue,
    //             bounce: false,
    //             body: JettonTransfer {
    //                 queryId: msg.queryId,
    //                 amount: msg.amount,
    //                 destination: ctx.sender,
    //                 responseDestination: ctx.sender,
    //                 customPayload: 0, // .store_uint(0, 1);
    //                 forwardTonAmount: 0,
    //                 forwardPayload: exitCode, // .store_uint(0, 1);
    //             }.toCell()
    //         });
    //     } else {
    //         if (opcode == swap) {
    //             let transferredMsg: Swap = Swap.fromSlice(payload);
    //             let poolAddress: Address = getPoolAddress(ctx.sender, token1Address);
    //             let ref = beginCell().storeAddress(msg.sender);
    //             if (transferredMsg.has_ref) {
    //                 ref = ref.storeAddress(transferredMsg.ref_address);
    //             }
    //             message(MessageParamaters{
    //                 to: poolAddress,
    //                 value: 0,
    //                 mode: SendRemainingValue,
    //                 bounce: false,
    //                 body: Swap {
    //                     queryId: msg.queryId,
    //                     toAddress: transferredMsg.toAddress,
    //                     senderAddress: ctx.sender,
    //                     jetton_amount: msg.amount,
    //                     min_out: transferredMsg.min_out,
    //                     has_ref: transferredMsg.has_ref,
    //                     ref: ref.endCell()
    //                 }.toCell()
    //             });
    //         }
            // } else if (opcode == provide_lp) {
            //     let transferredMsg: ProvideLP = ProvideLP.fromSlice(payload);
            //     let poolAddress = getPoolAddress(ctx.sender, token1Address);
            //     message(MessageParameters{
            //         to: poolAddress,
            //         value: 0,
            //         mode: SendRemainingValue,
            //         bounce: false,
            //         body: ProvideLP {
            //             queryId: msg.queryId,
            //             from_user: msg.sender,
            //             min_lp_out: transferredMsg.min_lp_out,
            //             amount0: msg.amount, 
            //             amount1: 0
            //         }.toCell()
            //     });    
            // }
    //     }
    // }  

    get fun getPoolAddress(token0Address: Address, token1Address: Address): Address {
        return getPoolAddress(token0Address, token1Address)
    }
}

