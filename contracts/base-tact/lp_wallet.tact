import "./messages";

inline fun getLPWalletStateInit(ownerAddress: Address, jettonMasterAddress: Address): StateInit {
    return initOf LPWallet(
        0,
        ownerAddress,
        jettonMasterAddress
    );
}

inline fun getLPWalletAddress(ownerAddress: Address, jettonMasterAddress: Address): Address {
    return contractAddress(getLPWalletStateInit(ownerAddress, jettonMasterAddress));
}

contract LPWallet {
    balance: Int as coins;
    ownerAddress: Address;
    jettonMasterAddress: Address;

    init(balance: Int, ownerAddress: Address, jettonMasterAddress: Address) {
        self.balance = balance;
        self.ownerAddress = ownerAddress;
        self.jettonMasterAddress = jettonMasterAddress;
    }

    receive(msg: JettonTransfer) {
        self.balance -= msg.amount;
        let toWalletAddress= getLPWalletAddress(msg.destination, self.jettonMasterAddress);
        send(SendParameters{
            to: toWalletAddress,
            value: 0,
            bounce: false,
            mode: SendRemainingValue,
            body: JettonTransferInternal {
                queryId: msg.queryId,
                amount: msg.amount,
                sender: self.ownerAddress,
                responseDestination: msg.responseDestination,
                forwardTonAmount: msg.forwardTonAmount,
                forwardPayload: msg.forwardPayload
            }.toCell()
        });
    }

    receive(msg: JettonTransferInternal) {
        self.balance += msg.amount;
        if (msg.forwardTonAmount > 0) {
            send(SendParameters{
                to: self.ownerAddress,
                value: 0,
                bounce: false, // TODO
                mode: SendRemainingValue, // TODO
                body: JettonNotification {
                    queryId: msg.queryId,
                    amount: msg.amount,
                    sender: msg.sender,
                    forwardPayload: msg.forwardPayload
                }.toCell()
            });
        }
    }

    receive(msg: JettonBurn) {
        self.balance -= msg.amount;
        send(SendParameters{
            to: self.jettonMasterAddress,
            value: 0,
            bounce: false, 
            mode: SendRemainingValue,
            body: JettonBurnNotification {
                queryId: msg.queryId,
                amount: msg.amount,
                sender: self.ownerAddress,
                responseDestination: msg.responseDestination
            }.toCell()
        });
    }
}