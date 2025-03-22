import { Blockchain, internal, printTransactionFees, SandboxContract, TreasuryContract } from '@ton/sandbox';
import { beginCell, Builder, toNano } from '@ton/core';
import '@ton/test-utils';
import { Router } from '../wrappers/Router';
import { Pool } from '../wrappers/Pool';
import { LPAccount } from '../wrappers/LPAccount';
import { PayTo } from '../wrappers/Router';


describe('Router', () => {
    let blockchain: Blockchain;
    let user: SandboxContract<TreasuryContract>;
    let router: SandboxContract<Router>;
    let pool: SandboxContract<Pool>;
    let token0: SandboxContract<TreasuryContract>;
    let token1: SandboxContract<TreasuryContract>;
    let lpAccount: SandboxContract<LPAccount>;
    

    beforeEach(async () => {
        blockchain = await Blockchain.create();
        user = await blockchain.treasury("user");
        token0 = await blockchain.treasury("token0Address");
        token1 = await blockchain.treasury("token1Address");
        router = blockchain.openContract(await Router
            .fromInit()
        );
        pool = blockchain.openContract(await Pool
            .fromInit(
                router.address, 
                token0.address, 
                token1.address, 
                0n, 
                0n, 
                0n
            )
        );
        lpAccount = blockchain.openContract(await LPAccount
            .fromInit(
                user.address, 
                pool.address, 
                toNano(0), 
                toNano(0)
            )
        );
        await pool.send(
            user.getSender(),
            {
                value: toNano('1'),
            }, 
            null
        )
        await router.send(
            user.getSender(),
            {
                value: toNano('1'),
            }, 
            null
        )
        await lpAccount.send(
            user.getSender(),
            {
                value: toNano('1'),
            }, 
            null
        )
    });

    it("should accept ProvideLP message", async () => {
        const send = await blockchain.sendMessage(internal({
            from: router.address,
            to: pool.address,
            value: toNano(1000000n),
            bounce: true,
            body: beginCell()
                    .storeUint(0xabababab, 32)
                    .storeUint(1n, 64)
                    .storeAddress(user.address)
                    .storeCoins(1n)
                    .storeCoins(1000n)
                    .storeCoins(0n)
                  .endCell()

        }));
        console.log("should accept ProvideLP message 1");

        printTransactionFees(send.transactions);

        expect(send.transactions).toHaveTransaction({
            from: router.address,
            to: pool.address,
            success: true,
        });
        expect(send.transactions).toHaveTransaction({
            from: pool.address,
            to: lpAccount.address,
            success: true,
        });

        const send1 = await blockchain.sendMessage(internal({
            from: router.address,
            to: pool.address,
            value: toNano(1000000n),
            bounce: true,
            body: beginCell()
                    .storeUint(0xabababab, 32)
                    .storeUint(1n, 64)
                    .storeAddress(user.address)
                    .storeCoins(1n)
                    .storeCoins(0n)
                    .storeCoins(1000n)
                  .endCell()

        }));

        console.log("should accept ProvideLP message 2");
        printTransactionFees(send1.transactions);

        expect(send1.transactions).toHaveTransaction({
            from: router.address,
            to: pool.address,
            success: true,
        });
        expect(send1.transactions).toHaveTransaction({
            from: pool.address,
            to: lpAccount.address,
            success: true,
        });

    });

    it("should accept Swap message", async () => {
        const send = await blockchain.sendMessage(internal({
            from: router.address,
            to: pool.address,
            value: toNano(1000000n),
            bounce: true,
            body: beginCell()
                    .storeUint(0xaaaaffff, 32)
                    .storeUint(0n, 64)
                    .storeAddress(user.address)
                    .storeAddress(token1.address)
                    .storeCoins(20000000000n)
                    .storeCoins(200n)
                  .endCell()
        }));
        console.log("should accept Swap message 1");
        printTransactionFees(send.transactions);

        expect(send.transactions).toHaveTransaction({
            from: router.address,
            to: pool.address,
            success: true,
        });
    });


});
