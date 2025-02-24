message Burn {
    query_id: Int;
    jetton_amount: Int;
    response_address: Address;
}

message AddLiquidity {
    query_id: Int;
    new_amount0: Int;
    new_amount1: Int;
    min_lp_out: Int;
}

message CbAddLiquidity {
    query_id: Int;
    amount0: Int;
    amount1: Int;
    user_address: Address;
    min_lp_out: Int;
}

