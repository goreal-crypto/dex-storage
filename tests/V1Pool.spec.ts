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
    let router: SandboxContract<TreasuryContract>;
    let pool: SandboxContract<Pool>;
    let token0: SandboxContract<TreasuryContract>;
    let token1: SandboxContract<TreasuryContract>;    

    beforeEach(async () => {
        blockchain = await Blockchain.create();
        user = await blockchain.treasury("user");
        token0 = await blockchain.treasury("token0Address");
        token1 = await blockchain.treasury("token1Address");
        router = await blockchain.treasury("router");
        pool = blockchain.openContract(await Pool
            .fromInit(
                router.address,
                20n,
                0n,
                10n, 
                token0.address, 
                token1.address, 
                0n, 
                0n, 
                0n,
                user.address,
                0n,
                0n
            )
        );
        await pool.send(
            user.getSender(),
            {
                value: toNano('1'),
            }, 
            null
        )
    });

    it("should accept ProvideLP message", async () => {
        const LPAccountAddress = await pool.getGetLpAccountAddress(user.address);
        const send = await pool.send(
            router.getSender(),
            {
                value: toNano(1)
            },
            {
                $$type: "ProvideLP",
                queryId: toNano(1),
                fromUser: user.address,
                minLPOut: toNano(1),
                amount0: toNano(1000),
                amount1: toNano(0)
            }   
        );
        expect(send.transactions).toHaveTransaction({
            from: pool.address,
            to: LPAccountAddress,
            success: true,
        });
        const send1 = await pool.send(
            router.getSender(),
            {
                value: toNano(1)
            },
            {
                $$type: "ProvideLP",
                queryId: toNano(1),
                fromUser: user.address,
                minLPOut: toNano(1),
                amount0: toNano(0),
                amount1: toNano(1000)
            }   
        );
        expect(send1.transactions).toHaveTransaction({
            from: pool.address,
            to: LPAccountAddress,
            success: true,
        });

    });

    it("should accept Swap message", async () => {
        const send = await pool.send(
            router.getSender(),
            {
                value: toNano(1)
            },
            {
                $$type: "Swap",
                queryId: toNano(0),
                fromAddress: user.address,
                tokenWallet: token1.address,
                jettonAmount: toNano(200000),
                minOutput: toNano(200),
                hasRef: false,
                fromRealUser: user.address,
                refAddress: null
            }  
        )
        console.log("should accept Swap message 1");
        printTransactionFees(send.transactions);

        expect(send.transactions).toHaveTransaction({
            from: router.address,
            to: pool.address,
            success: true,
        });
    });


});
