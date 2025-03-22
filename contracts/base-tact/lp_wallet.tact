import "./messages";

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
        self.balance = self.balance - msg.jetton_amount;
        send(SendParameters{
            to: ,
            value: 0,
            bounce: false, // TODO
            mode: SendRemainingValue, // TODO
            body: InternalTransfer {
                query_id: msg.query_id,
                jetton_amount: msg.jetton_amount,
                owner_address: self.owner_address,
                response_address: msg.response_address,
                forward_ton_amount: msg.forward_ton_amount,
                either_forward_payload: msg.either_forward_payload
            }
        });
    }

    receive(msg: InternalTransfer) {
        self.balance += msg.jetton_amount;
        if (msg.forward_ton_amount) {
            send(SendParameters{
                to: self.owner_address,
                value: 0,
                bounce: false, // TODO
                mode: SendRemainingValue, // TODO
                body: TransferNotification {
                    query_id: msg.query_id,
                    jetton_amount: msg.jetton_amount,
                    from_address: msg.from_address,
                    either_forward_payload: msg.either_forward_payload
                }
            });
        }
    }

    receive(msg: Burn) {
        self.balance = self.balance - msg.jetton_amount;
        send(SendParameters{
            to: self.jetton_master_address,
            value: 0,
            bounce: false, // TODO
            mode: SendRemainingValue, // TODO
            body: BurnNotification {
                query_id: msg.query_id,
                jetton_amount: msg.jetton_amount,
                from_address: self.owner_address,
                response_address: msg.response_address
            }
        });
    }
}