import { Blockchain, internal, printTransactionFees, SandboxContract, TreasuryContract } from '@ton/sandbox';
import { beginCell, Builder, toNano } from '@ton/core';
import '@ton/test-utils';
import { Router } from '../wrappers/Router';
import { Pool } from '../build/V1Pool/tact_Pool';
import { LPAccount } from '../wrappers/LPAccount';
import { PayTo } from '../wrappers/Router';
import { getUsedGasInternal } from '../utils/gas';


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
    const mint = async (amount0: bigint, amount1: bigint) => {
        const LPAccountAddress = await pool.getGetLpAccountAddress(user.address);
        const poolStateBefore = await pool.getGetPoolData()
        const mint0 = await pool.send(
            router.getSender(),
            {
                value: toNano("1")
            },
            {
                $$type: "ProvideLP",
                queryId: 1n,
                fromUser: user.address,
                minLPOut: 1n,
                amount0: amount0,
                amount1: 0n
            }   
        );
        expect(mint0.transactions).toHaveTransaction({
            from: pool.address,
            to: LPAccountAddress,
            success: true,
        });
        const mint1 = await pool.send(
            router.getSender(),
            {
                value: toNano("1")
            },
            {
                $$type: "ProvideLP",
                queryId: 1n,
                fromUser: user.address,
                minLPOut: 1n,
                amount0: 0n,
                amount1: amount1
            }   
        );
        expect(mint1.transactions).toHaveTransaction({
            from: pool.address,
            to: LPAccountAddress,
            success: true,
        });
        expect(mint1.transactions).toHaveTransaction({
            from: LPAccountAddress,
            to: pool.address,
            success: true
        })
        const poolStateAfter = await pool.getGetPoolData()
        expect(poolStateAfter.reserve0).toBe(poolStateBefore.reserve0 + amount0)
        expect(poolStateAfter.reserve1).toBe(poolStateBefore.reserve1 + amount1)
        console.log("mint1", getUsedGasInternal(mint0, {type: "chain"}))
        console.log("mint2", getUsedGasInternal(mint1, {type: "chain"}))
        console.log("mint", getUsedGasInternal(mint0, {type: "chain"}) + getUsedGasInternal(mint1, {type: "chain"}))


        return {mint0, mint1}
    }


    it("should accept Swap message", async () => {
        await mint(100000n, 1000000n)
        const send = await pool.send(
            router.getSender(),
            {
                value: toNano(1)
            },
            {
                $$type: "Swap",
                queryId: toNano(0),
                fromAddress: user.address,
                tokenWallet: token0.address,
                jettonAmount: 2000n,
                minOutput: 200n,
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
        console.log("SWAP", getUsedGasInternal(send, {type: "chain"}))

        let poolData = await pool.getGetPoolData();
        console.log(poolData)
    });
});
