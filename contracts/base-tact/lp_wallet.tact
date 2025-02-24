message Burn {
    query_id: Int;
    jetton_amount: Int;
    response_address: Address;
}

contract Wallet {
    balance: Int;
    owner_address: Address;
    jetton_master_address: Address;
    jetton_wallet_code: Cell;

    receive(msg: Transfer) {
        // TODO
    }

    receive(msg: InternalTransfer) {
        // TODO
    }

    receive(msg: Burn) {
        self.balance = self.balance - msg.jetton_amount;
        send(SendParameters{
            to: self.jetton_master_address,
            value: 0,
            bounce: false, // TODO
            mode: SendRemainingValue, // TODO
            body: BurnNotification {

            }
        });
    }
}