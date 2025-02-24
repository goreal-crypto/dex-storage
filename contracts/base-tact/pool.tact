contract Pool {
    router_address: Address;
    lp_fee: Int;
    protocol_fee: Int;
    ref_fee: Int;
    token0_address: Address;
    token1_address: Address;
    total_supply_lp: Int; 
    collected_token0_protocol_fee: Int;
    collected_token1_protocol_fee: Int; 
    protocol_fee_address: Address;
    reserve0: Int;
    reserve1: Int; 
    jetton_lp_wallet_code: Cell;
    lp_account_code: Cell;

    receive(msg: BurnNotification) {

    }

    receive(msg: CbAddLiquidity) {

    }

    receive(msg: CbRefundMe) {

    }

    receive(msg: CollectFees) {

    }
}