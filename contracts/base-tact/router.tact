message PayTo {
    owner: Address;
    exit_code: Int;
    amount0_out: Int;
    token0_address: Address;
    amount1_out: Int;
    token1_address: Address;
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

contract Router {
    is_locked: Bool;
    admin_address: Address;
    jetton_lp_wallet_code: Cell; 
    pool_code: Cell;
    lp_account_code: Cell; 
    temp_upgrade: Cell;

    receive(msg: PayTo) {
        let gas_required = get_gas_fee(20000, WORKCHAIN); // TODO
        let msg_value = context().value;
        throwUnless(INSUFFICIENT_GAS, msg_value > gas_required);
        let pool_address = getPoolAddress(msg.token0_address, msg.token1_address);
        throwUnless(INVALID_CALLER, pool_address == sender());

        let ton_amount = 0;
        let mode = SendRemainingValue;
        if ((amount0_out > 0) && (amount1_out > 0)) {
            ton_amount = (msg_value - gas_required) / 2;
            mode = SendDefaultMode;
        }
        if (amount0_out > 0) {
            message(MessageParamaters{
                to: token0_address,
                value: ton_amount,
                mode: mode,
                bounce: false, // ?
                body: JettonTransfer {
                    queryId: msg.query_id,
                    amount: amount0_out,
                    destination: msg.owner,
                    responseDestination: msg.owner,
                    customPayload: 0, // .store_uint(0, 1);
                    forwardTonAmount: 0,
                    forwardPayload: 0, // .store_uint(0, 1);
                }.toCell();
            });
        }
        if (amount1_out > 0) {
            message(MessageParamaters{
                to: token1_address,
                value: ton_amount,
                mode: mode,
                bounce: false, // ?
                body: JettonTransfer {
                    queryId: msg.query_id,
                    amount: amount1_out,
                    destination: msg.owner,
                    responseDestination: msg.owner,
                    customPayload: 0, // .store_uint(0, 1);
                    forwardTonAmount: 0,
                    forwardPayload: 0, // .store_uint(0, 1);
                }.toCell();
            });
        }
    }

    receive(msg: JettonNotification) {
        
    }    
}

// TODO
inline fun getPoolStateInit(token0_address: Address, token1_address: Address): StateInit {
    return initOf Pool(
        myAddress(), // router_address
        0,           // lp_fee
        0,           // ref_fee
        token0_address, // token0_address
        token1_address, // token1_address
        0,           // total_supply_lp
        0,           // collected_token0_protocol_fee
        0,           // collected_token1_protocol_fee
        ?,           // protocol_fee_address
        0,           // reserve0
        0,           // reserve1
    );
}

inline fun getPoolAddress(token0_address: Address, token1_address: Address) : Address {
    return contractAddress(getPoolStateInit(token0_address, token1_address));
}