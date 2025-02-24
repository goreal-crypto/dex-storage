contract Router {
    is_locked: Bool;
    admin_address: Address;
    jetton_lp_wallet_code: Cell; 
    pool_code: Cell;
    lp_account_code: Cell; 
    temp_upgrade: Cell;

    receive(msg: PayTo) {
        // TODO
    }

    receive(msg: TransferNotification) {
        // TODO
    }

    
}