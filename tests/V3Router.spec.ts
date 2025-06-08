import { Blockchain, internal, printTransactionFees, SandboxContract, TreasuryContract } from '@ton/sandbox';
import { beginCell, Builder, Dictionary, toNano } from '@ton/core';
import '@ton/test-utils';
import { encodeSqrtRatioX96, getMaxTick, getMinTick } from '../utils/math';
import { TickMathTest } from '../build/TickMathTest/tact_TickMathTest';
import { getUsedGasInternal } from '../utils/gas';
import { Router } from '../build/V3Router/tact_Router';


describe("V3Router", () => {
    let blockchain: Blockchain;
    let user: SandboxContract<TreasuryContract>;
    let admin: SandboxContract<TreasuryContract>;
    let router: SandboxContract<Router>;
    let token0: SandboxContract<TreasuryContract>;
    let token1: SandboxContract<TreasuryContract>;
    let token2: SandboxContract<TreasuryContract>;


    beforeEach(async () => {
        blockchain = await Blockchain.create();
        user = await blockchain.treasury("user");
        admin = await blockchain.treasury("admin");
        token0 = await blockchain.treasury("token0Address");
        token1 = await blockchain.treasury("token1Address");
        token2 = await blockchain.treasury("token2Address");
        router = blockchain.openContract(await Router.fromInit(admin.address));
    });

    it("should initialize pool", async () => {
        const send = await router.send(
            admin.getSender(),
            {value: toNano("0.5")},
            {
                $$type: "PoolInitialize",
                queryId: 0n,
                token0Address: token0.address,
                token1Address: token1.address,
                sqrtPriceX96: 1n,
            }
        )
        // printTransactionFees(send.transactions)
        const poolAddress = await router.getPoolAddress(token0.address, token1.address);
        expect(send.transactions).toHaveTransaction({
            to: poolAddress,
            from: router.address,
            deploy: true
        })
    })

    it("should route provide liquidity", async () => {
        const deploy = await router.send(
            admin.getSender(),
            {value: toNano("0.5")},
            {
                $$type: "PoolInitialize",
                queryId: 0n,
                token0Address: token0.address,
                token1Address: token1.address,
                sqrtPriceX96: 1n,
            }
        ) 


        const provide = await router.send(
            token0.getSender(),
            {value: toNano("0.5")},
            {
                $$type: "JettonNotification",
                queryId: 1n,
                amount: 100000000n,
                sender: user.address,
                forwardPayload: beginCell()
                    .storeUint(0xfffffff2n, 32)
                    .storeAddress(token1.address)
                    .storeCoins(1000n)
                    .storeCoins(1000n)
                    .storeUint(10, 128)
                    .storeInt(-1000n, 24)
                    .storeInt(1000, 24)
                    .endCell()
                .asSlice()
            }
        )

        printTransactionFees(provide.transactions);
        const poolAddress = await router.getPoolAddress(token0.address, token1.address);
        expect(provide.transactions).toHaveTransaction({
            to: poolAddress,
            from: router.address,
            success: true
        })    
    })

    it("should route swap", async () => {
        const deploy = await router.send(
            admin.getSender(),
            {value: toNano("0.5")},
            {
                $$type: "PoolInitialize",
                queryId: 0n,
                token0Address: token0.address,
                token1Address: token1.address,
                sqrtPriceX96: 1n,
            }
        ) 


        const swap = await router.send(
            token0.getSender(),
            {value: toNano("0.5")},
            {
                $$type: "JettonNotification",
                queryId: 1n,
                amount: 100000000n,
                sender: user.address,
                forwardPayload: beginCell()
                    .storeUint(0xfffffff1n, 32)
                    .storeAddress(token1.address)
                    .storeUint(10000000n, 160)
                    .endCell()
                .asSlice()
            }
        )

        printTransactionFees(swap.transactions);
        const poolAddress = await router.getPoolAddress(token0.address, token1.address);
        expect(swap.transactions).toHaveTransaction({
            to: poolAddress,
            from: router.address,
            success: true
        })    
    })
});