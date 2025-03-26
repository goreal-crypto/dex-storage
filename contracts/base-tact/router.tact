import "./pool";
import "./messages";


// TODO
inline fun getPoolStateInit(token0Address: Address, token1Address: Address): StateInit {
    return initOf Pool(
        myAddress(), // routerAddress
        // 0,           // lp_fee
        // 0,           // ref_fee
        token0Address, // token0Address
        token1Address, // token1Address
        0,           // totalSupplyLP
        // 0,           // collected_token0_protocol_fee
        // 0,           // collected_token1_protocol_fee
        // ?,           // protocol_fee_address
        0,           // reserve0
        0,           // reserve1
    );
}

inline fun getPoolAddress(token0Address: Address, token1Address: Address): Address {
    return contractAddress(getPoolStateInit(token0Address, token1Address));
}


contract Router {
    // isLocked: Bool;
    adminAddress: Address;
    // jetton_lp_wallet_code: Cell; 
    // pool_code: Cell;
    // lp_account_code: Cell; 
    // temp_upgrade: Cell;
    receive(adminAddress: Address){
        self.adminAddress = adminAddress;
    }

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
            if (opcode == SWAP) {
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
            } else if (opcode == PROVIDE_LP) {
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
                        fromUser: msg.sender,
                        minLPOut: minLPOut,
                        amount0: msg.amount, // 0
                        amount1: 0 // msg.amount
                    }.toCell()
                });    
            }
        }
    }  
    

// TODO admin calls

    // receive(msg: SetFees) {

        // throwUnless(INVALID_CALLER, sender() == self.adminAddress);
    //     let (newLpFee, newProtocolFee, newRefFee, newProtocolFeeAddress) = (msg.lpFee, msg.protocolFee, msg.refFee, msg.protocolFeeAddress);
    //     let (jettonWallet0, jettonWallet1) = (msg.jettonWallet0, msg.jettonWallet1);
    //     let (_, poolAddress) = getPoolStateInitAndAddress(jettonWallet0, jettonWallet1);
        
    //     let body = beginCell()
    //         .store_uint(set_fees, 32)
    //         .store_uint(context().query_id, 64)
    //         .store_uint(newLpFee, 8)
    //         .store_uint(newProtocolFee, 8)
    //         .store_uint(newRefFee, 8)
    //         .store_slice(newProtocolFeeAddress);
    //     send_simple_message(0, poolAddress, body.end_cell(), CARRY_REMAINING_GAS);
    // }

    // receive(msg: CollectFees) {
            // throwUnless(INVALID_CALLER, sender() == self.adminAddress);

    //     let (jettonWallet0, jettonWallet1) = (msg.jettonWallet0, msg.jettonWallet1);
    //     let (_, poolAddress) = getPoolStateInitAndAddress(jettonWallet0, jettonWallet1);
    //     let body = beginCell()
    //         .store_uint(collect_fees, 32)
    //         .store_uint(context().query_id, 64);
    //     send_simple_message(0, poolAddress, body.end_cell(), CARRY_REMAINING_GAS);
    // }

    // receive(msg: Lock) {
            // throwUnless(INVALID_CALLER, sender() == self.adminAddress);

    //     self.isLocked = true;
    // }
    
    // receive(msg: Unlock) {
            // throwUnless(INVALID_CALLER, sender() == self.adminAddress);

    //     self.isLocked = false;
    // }

    
    // receive(msg: ResetGas) {
            // throwUnless(INVALID_CALLER, sender() == self.adminAddress);

    //     message(MessageParameters{
    //          to: self.adminAddress
    //          value: my_balance - REQUIRED_TON_RESERVE,
    //          mode: SendDefaultMode,
    //          bounce: false,
    //          body: empty
    //  });
    // }
    
    // receive(msg: ResetPoolGas) {
            // throwUnless(INVALID_CALLER, sender() == self.adminAddress);

    //     let (jettonWallet0, jettonWallet1) = (msg.jettonWallet0, msg.jettonWallet1);
    //     let (_, poolAddress) = getPoolStateInitAndAddress(jettonWallet0, jettonWallet1);
    //     let body = beginCell().store_uint(reset_gas, 32).store_uint(context().query_id, 64);
    //     send_simple_message(0, poolAddress, body.end_cell(), CARRY_REMAINING_GAS);
        //     message(MessageParameters{
    //          to: poolAddress
    //          value: 0,
    //          mode: SendRemainingValue,
    //          bounce: false,
    //          body: body
    //  });
    // }


    get fun getPoolAddress(token0Address: Address, token1Address: Address): Address {
        return getPoolAddress(token0Address, token1Address)
    }
}