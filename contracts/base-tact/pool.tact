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

const ZERO_OUTPUT: Int = 1235;

contract Pool {
    // router_address: Address;
    // lp_fee: Int;
    // protocol_fee: Int;
    // ref_fee: Int;
    token0Address: Address;
    token1Address: Address;
    // total_supply_lp: Int; 
    // collected_token0_protocol_fee: Int;
    // collected_token1_protocol_fee: Int; 
    // protocol_fee_address: Address;
    // reserve0: Int;
    // reserve1: Int; 
    // // jetton_lp_wallet_code: Cell;
    // // lp_account_code: Cell;

    init(token0Address: Address, token1Address: Address) {
        self.token0Address = token0Address;
        self.token1Address = token1Address;
    }

    receive(){}

//     receive(msg: BurnNotification) {
//         // throwUnless(INSUFFICIENT_GAS, (msg_value > gas_required) & (msg_value > cs~load_coins() * 6));
//         // throwUnless(INVALID_CALLER, equal_slices(calculate_user_jetton_lp_wallet_address(from_address, my_address(), storage::jetton_lp_wallet_code), sender_address));
//         throwUnless(ZERO_OUTPUT, msg.jetton_amount > 0);
//         let amount0_out = (msg.jetton_amount * self.reserve0) / self.total_supply_lp;
//         let amount1_out = (msg.jetton_amount * self.reserve1) / self.total_supply_lp;
//         throwUnless(ZERO_OUTPUT, (amount0_out > 0) && (amount1_out > 0));
//         self.reserve0 -= amount0_out;
//         self.reserve1 -= amount1_out;
//         self.total_supply_lp -= msg.jetton_amount;
        
//         let gas = 0;
//         let mode = SendRemainingValue;
//         // TODO: send excesses

//         message(MessageParamaters{
//             to: self.router_address,
//             value: gas,
//             mode: mode,
//             bounce: false,
//             body: PayTo{
//                 query_id: msg.query_id,
//                 exit_code: , // TODO
//                 to_address: msg.from_address,
//                 amount0: amount0_out,
//                 token0Address: self.token0Address,
//                 amount1: amount1_out,
//                 token1Address: self.token1Address,
//             }.toCell()
//         });
//     }

//     receive(msg: CbAddLiquidity) {
//         let liquidity = 0;
//         let to = "";

//         if (self.total_supply_lp == 0) {
//             liquidity = sqrt(msg.amount0 * msg.amount1) / self.reserve0;
//             to = addr_none() // TODO
//         } else {
//             let to_mint0 = (msg.amount0 * self.total_supply_lp) / self.reserve0;
//             let to_mint1 = (msg.amount1 * self.total_supply_lp) / self.reserve1;
//             liquidity = min(to_mint0, to_mint1);

//             to = user_address;
//         }

//         self.reserve0 += msg.amount0;
//         self.reserve1 += msg.amount1;
//         self.total_supply_lp += liquidity;

//         if ((liquidity < msg.min_lp_out) || ((self.reserve0 > MAX_COINS) || (self.reserve1 > MAX_COINS))) {
//             send(SendParameters{
//                 to: // ?,
//                 value: 0,
//                 bounce: false,
//                 mode: SendRemainingValue,
//                 body: AddLiquidity {
//                     query_id: msg.query_id,
//                     new_amount0: tot_am0,
//                     new_amount1: tot_am1,
//                     min_lp_out: 0
//                 }.toCell()
//             });
//         } else {

//         }
//     }

//     receive(msg: CbRefundMe) {
//         // call_pay_to(0, CARRY_REMAINING_GAS, query_id, user_address, refund_ok, tot_am0, tot_am1);
//         message(MessageParamaters{
//             to: self.router_address,
//             value: 0,
//             mode: SendRemainingValue,
//             bounce: false,
//             body: PayTo{
//                 query_id: msg.query_id,
//                 to_address: msg.user_address,
//                 amount0: amount0_out,
//                 token0Address: self.token0Address,
//                 amount1: amount1_out,
//                 token1Address: self.token1Address,
//             }.toCell()
//         });
//     }

//     receive(msg: CollectFees) {
//         let reward0 = self.collected_token0_protocol_fee / 1000;
//         let reward1 = self.collected_token1_protocol_fee / 1000;
        
//         // call_pay_to(gas * 3, NORMAL, query_id, storage::protocol_fee_address, 0, storage::collected_token0_protocol_fee, storage::collected_token1_protocol_fee); ;; revert if fails
//         // call_pay_to(gas, IGNORE_ERRORS, query_id, sender_address, 0, reward0, reward1);

//         self.collected_token0_protocol_fee -= reward0;
//         self.collected_token1_protocol_fee -= reward1;

//     }

    receive(msg: Swap) {

    }

    receive(msg: ProvideLP) {

    }

//     receive(msg: ResetGas) {

//     }

//     receive(msg: SetFees) {

//     }
}