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
        let amount0_out = (msg.jetton_amount * self.reserve0) / self.total_supply_lp;
        let amount1_out = (msg.jetton_amount * self.reserve1) / self.total_supply_lp;
        self.reserve0 = self.reserve0 - amount0_out;
        self.reserve1 = self.reserve1 - amount1_out;
        self.total_supply_lp = self.total_supply_lp - msg.jetton_amount;
    }

    receive(msg: CbAddLiquidity) {
        let liquidity = 0;
        let to = "";

        if (self.total_supply_lp == 0) {
            liquidity = sqrt(msg.tot_am0 * self.total_supply_lp) / self.reserve0;
            to = addr_node()
        } else {
            let to_mint0 = (tot_am0 * self.total_supply_lp) / self.reserve0;
            let to_mint1 = (tot_am1 * self.total_supply_lp) / self.reserve1;
            liquidity = min(to_mint0, to_mint1);

            to = user_address;
        }

        self.reserve0 = self.reserve0 + tot_am0;
        self.reserve1 = self.reserve1 + tot_am1;
        self.total_supply_lp = self.total_supply_lp + liquidity;

        if ((liquidity < msg.min_lp_out) | ((self.reserve0 > MAX_COINS) | (self.reserve1 > MAX_COINS))) {
            send(SendParameters{
                to: // ?,
                value: 0,
                bounce: false,
                mode: SendRemainingValue,
                body: AddLiquidity {
                    query_id: msg.query_id,
                    tot_am0: tot_am0,
                    tot_am1: tot_am1,
                    // 0
                }
            });
        }
    }

    receive(msg: CbRefundMe) {
        // call_pay_to(0, CARRY_REMAINING_GAS, query_id, user_address, refund_ok, tot_am0, tot_am1);
    }

    receive(msg: CollectFees) {
        let reward0 = self.collected_token0_protocol_fee / 1000;
        let reward1 = self.collected_token1_protocol_fee / 1000;
        
        // call_pay_to(gas * 3, NORMAL, query_id, storage::protocol_fee_address, 0, storage::collected_token0_protocol_fee, storage::collected_token1_protocol_fee); ;; revert if fails
        // call_pay_to(gas, IGNORE_ERRORS, query_id, sender_address, 0, reward0, reward1);

        self.collected_token0_protocol_fee = self.collected_token0_protocol_fee - reward0;
        self.collected_token1_protocol_fee = self.collected_token0_protocol_fee = reward1;

    }
}