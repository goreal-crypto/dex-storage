import { Blockchain, printTransactionFees, SandboxContract, TreasuryContract } from '@ton/sandbox';
import { toNano } from '@ton/core';
import '@ton/test-utils';
import { LPAccount } from '../wrappers/LPAccount';

describe('LPAccount', () => {
    let blockchain: Blockchain;
    let pool: SandboxContract<TreasuryContract>;
    let user: SandboxContract<TreasuryContract>;
    let lpAccount: SandboxContract<LPAccount>;

    beforeEach(async () => {
        blockchain = await Blockchain.create();
        pool = await blockchain.treasury("pool");
        user = await blockchain.treasury("user");
        lpAccount = blockchain.openContract(await LPAccount
            .fromInit(
                user.address, 
                pool.address, 
                toNano(0), 
                toNano(0)
            )
        );
    });

    it("should store new liquidity and ask for minting", async () => {
        let wrongSender = await blockchain.treasury("wrongSender");
        const sendWrongSender = await lpAccount.send(
            wrongSender.getSender(),
            {
                value: toNano(1)
            },
            {
                $$type: "AddLiquidity",
                query_id: toNano(1),
                new_amount0: toNano(1),
                new_amount1: toNano(0),
                min_lp_out: toNano(1),
            }
        );

        printTransactionFees(sendWrongSender.transactions);
        expect(sendWrongSender.transactions).toHaveTransaction({
            from: wrongSender.address,
            to: lpAccount.address,
            success: false,
        });
        
        const send = await lpAccount.send(
            pool.getSender(),
            {
                value: toNano(1)
            },
            {
                $$type: "AddLiquidity",
                query_id: toNano(1),
                new_amount0: toNano(1),
                new_amount1: toNano(0),
                min_lp_out: toNano(1),
            }
        );

        printTransactionFees(send.transactions);
        expect(send.transactions).toHaveTransaction({
            from: pool.address,
            to: lpAccount.address,
            success: true,
        });
        
        const sendCB = await lpAccount.send(
            pool.getSender(),
            {
                value: toNano(1)
            },
            {
                $$type: "AddLiquidity",
                query_id: toNano(1),
                new_amount0: toNano(0),
                new_amount1: toNano(10),
                min_lp_out: toNano(1),
            }
        );

        printTransactionFees(sendCB.transactions);
        expect(sendCB.transactions).toHaveTransaction({
            from: pool.address,
            to: lpAccount.address,
            success: true,
        });

        const sendRefund = await lpAccount.send(
            pool.getSender(),
            {
                value: toNano(1)
            },
            {
                $$type: "AddLiquidity",
                query_id: toNano(1),
                new_amount0: toNano(0),
                new_amount1: toNano(10),
                min_lp_out: toNano(0),
            }
        );

        printTransactionFees(sendRefund.transactions);
        expect(sendRefund.transactions).toHaveTransaction({
            from: pool.address,
            to: lpAccount.address,
            success: true,
        });

    });

    it("should ask for minting new liquidity directly", async () => {
        let wrongSender = await blockchain.treasury("wrongSender");
        const sendWrongSender = await lpAccount.send(
            wrongSender.getSender(),
            {
                value: toNano(1)
            },
            {
                $$type: "DirectAddLiquidity",
                query_id: toNano(1),
                amount0: toNano(1),
                amount1: toNano(0),
                min_lp_out: toNano(1),  
            }
        );

        printTransactionFees(sendWrongSender.transactions);
        expect(sendWrongSender.transactions).toHaveTransaction({
            from: wrongSender.address,
            to: lpAccount.address,
            success: false,
        });

        const sendLowBalance = await lpAccount.send(
            user.getSender(),
            {
                value: toNano(1)
            },
            {
                $$type: "DirectAddLiquidity",
                query_id: toNano(1),
                amount0: toNano(1),
                amount1: toNano(0),
                min_lp_out: toNano(1),
            }
        );

        printTransactionFees(sendLowBalance.transactions);
        expect(sendLowBalance.transactions).toHaveTransaction({
            from: user.address,
            to: lpAccount.address,
            success: false,
        });

        const addAmount = await lpAccount.send(
            pool.getSender(),
            {
                value: toNano(10)
            },
            {
                $$type: "AddLiquidity",
                query_id: toNano(1),
                new_amount0: toNano(10),
                new_amount1: toNano(10),
                min_lp_out: toNano(0),
            }
        );

        const send = await lpAccount.send(
            user.getSender(),
            {
                value: toNano(1)
            },
            {
                $$type: "DirectAddLiquidity",
                query_id: toNano(1),
                amount0: toNano(1),
                amount1: toNano(3),
                min_lp_out: toNano(1),
            }
        );

        printTransactionFees(send.transactions);
        expect(send.transactions).toHaveTransaction({
            from: user.address,
            to: lpAccount.address,
            success: true,
        });
    });

    it("should refund user", async () => {
        let wrongSender = await blockchain.treasury("wrongSender");
        const sendWrongSender = await lpAccount.send(
            wrongSender.getSender(),
            {
                value: toNano(1)
            },
            {
                $$type: "RefundMe",
                query_id: toNano(1), 
            }
        );
        printTransactionFees(sendWrongSender.transactions);
        expect(sendWrongSender.transactions).toHaveTransaction({
            from: wrongSender.address,
            to: lpAccount.address,
            success: false,
        });

        const sendLowBalance = await lpAccount.send(
            user.getSender(),
            {
                value: toNano(1)
            },
            {
                $$type: "RefundMe",
                query_id: toNano(1),
            }
        );

        printTransactionFees(sendLowBalance.transactions);
        expect(sendLowBalance.transactions).toHaveTransaction({
            from: user.address,
            to: lpAccount.address,
            success: false,
        });

        const addAmount = await lpAccount.send(
            pool.getSender(),
            {
                value: toNano(10)
            },
            {
                $$type: "AddLiquidity",
                query_id: toNano(1),
                new_amount0: toNano(10),
                new_amount1: toNano(10),
                min_lp_out: toNano(0),
            }
        );

        const send = await lpAccount.send(
            user.getSender(),
            {
                value: toNano(1)
            },
            {
                $$type: "RefundMe",
                query_id: toNano(1),
            }
        );

        printTransactionFees(send.transactions);
        expect(send.transactions).toHaveTransaction({
            from: user.address,
            to: lpAccount.address,
            success: true,
        });
    });
});