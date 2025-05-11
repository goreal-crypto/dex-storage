import { Blockchain, internal, printTransactionFees, SandboxContract, TreasuryContract } from '@ton/sandbox';
import { beginCell, Builder, Dictionary, toNano } from '@ton/core';
import '@ton/test-utils';
import { Pool } from '../build/V3Pool/tact_Pool';
import { encodeSqrtRatioX96, getMaxTick, getMinTick } from '../utils/math';
import { TickMathTest } from '../build/TickMathTest/tact_TickMathTest';
import { getUsedGasInternal } from '../utils/gas';

describe("V3Pool", () => {
    let blockchain: Blockchain;
    let user: SandboxContract<TreasuryContract>;
    let admin: SandboxContract<TreasuryContract>;
    let router: SandboxContract<TreasuryContract>;
    let pool: SandboxContract<Pool>;
    let token0: SandboxContract<TreasuryContract>;
    let token1: SandboxContract<TreasuryContract>;

    const mint = async (tickLower: bigint, tickUpper: bigint, liquidity: bigint) => {
        const amounts = await pool.getGetMintEstimate(tickLower, tickUpper, liquidity);
        console.log("Mint amounts:", amounts);
        await pool.send(
            router.getSender(),
            { value: toNano("1") },
            {
                $$type: "ProvideLiquidity",
                queryId: 0n,
                userAddress: user.address,
                amount0: 0n,
                amount1: amounts.amount1,
                enough0: amounts.amount0,
                enough1: amounts.amount1,
                liquidity,
                tickLower,
                tickUpper
            }
        );
        await pool.send(
            router.getSender(),
            { value: toNano("1") },
            {
                $$type: "ProvideLiquidity",
                queryId: 0n,
                userAddress: user.address,
                amount0: amounts.amount0,
                amount1: 0n,
                enough0: amounts.amount0,
                enough1: amounts.amount1,
                liquidity,
                tickLower,
                tickUpper
            }
        );
        return amounts;
    };

    beforeEach(async () => {
        blockchain = await Blockchain.create();
        user = await blockchain.treasury("user");
        admin = await blockchain.treasury("admin");
        router = await blockchain.treasury("router");
        token0 = await blockchain.treasury("token0Address");
        token1 = await blockchain.treasury("token1Address");
        pool = blockchain.openContract(await Pool.fromInit(
            router.address,
            token0.address,
            token1.address,
            0n,
            0n,
            0n,
            Dictionary.empty(),
            1n,
            0n,
            0n,
            0n,
            100n
        ));
    });

    it("initialize", async () => {
        const deploy = await pool.send(
            admin.getSender(),
            {value: toNano("1")},
            {
                $$type: "Initialize",
                queryId: 0n,
                sqrtPriceX96: BigInt(encodeSqrtRatioX96(1,1).toString())
            }
        )   
        printTransactionFees(deploy.transactions);
    });

    describe("mint", () => {
        beforeEach(async () => {
            const deploy = await pool.send(
                admin.getSender(),
                {value: toNano("1")},
                {
                    $$type: "Initialize",
                    queryId: 0n,
                    sqrtPriceX96: BigInt(encodeSqrtRatioX96(1,1).toString())
                }
            )   
            const amounts = await pool.getGetMintEstimate(BigInt(getMinTick(60)), BigInt(getMaxTick(60)), 3161n);
            console.log(amounts)
        });  
        it("1", async () => {
            const liquidity = 2n * (10n ** 18n)
            await mint(-22980n, 0n, liquidity);
            let tickLower = await pool.getGetTicks(-22980n);
            expect(tickLower?.liquidityNet).toBe(liquidity);
            let tickUpper = await pool.getGetTicks(0n);
            expect(tickUpper?.liquidityNet).toBe(-liquidity);
        });

        it("2", async () => {
            const liquidity1 = 2n * (10n ** 18n)
            await mint(-8000n, 8000n, liquidity1);
            console.log(await pool.getGetPoolState());
            const liquidity2 = 2n * (10n ** 18n)
            await mint(-200n, 200n, liquidity2);
            console.log(await pool.getGetTicks(-200n))
            console.log(await pool.getGetTicks(200n))
            console.log(await pool.getGetTicks(8000n))
            console.log(await pool.getGetTicks(-8000n))
        });

        it("multiple overlapping positions", async () => {
            const L1 = 1n * (10n ** 18n);
            const L2 = 2n * (10n ** 18n);
            await mint(-1000n, 1000n, L1);
            await mint(-500n, 500n, L2);
            const t0 = await pool.getGetTicks(-1000n);
            const t1 = await pool.getGetTicks(-500n);
            expect(t0?.liquidityNet).toBe(L1);
            expect(t1?.liquidityNet).toBe(L2);
        });
        it("mint multiple times to same range", async () => {
            const tickLower = -1000n;
            const tickUpper = 1000n;
            const L1 = 1n * 10n ** 18n;
            const L2 = 2n * 10n ** 18n;
        
            await mint(tickLower, tickUpper, L1);
            await mint(tickLower, tickUpper, L2);
        
            const lower = await pool.getGetTicks(tickLower);
            const upper = await pool.getGetTicks(tickUpper);
        
            expect(lower?.liquidityNet).toBe(L1 + L2);
            expect(upper?.liquidityNet).toBe(-(L1 + L2));
        });
        it("mint entirely above and below current tick", async () => {
            const liquidity = 1n * 10n ** 18n;
        
            // current tick == 0
            await mint(100n, 200n, liquidity); // above current tick
            await mint(-200n, -100n, liquidity); // below current tick
        
            const poolState = await pool.getGetPoolState();
            // liquidity на диапазонах вне current tick не влияет на текущую активную ликвидность
            expect(poolState.liquidity).toBe(0n);
        });
        it("mint across current tick increases active liquidity", async () => {
            const liquidity = 1n * 10n ** 18n;
            await mint(-100n, 100n, liquidity);
        
            const state = await pool.getGetPoolState();
            expect(state.liquidity).toBe(liquidity);
        });
        it("mint on full range (MIN_TICK to MAX_TICK)", async () => {
            const liquidity = 1n * 10n ** 18n;
            const tickLower = BigInt(getMinTick(1));
            const tickUpper = BigInt(getMaxTick(1));
        
            await mint(tickLower, tickUpper, liquidity);
        
            const lower = await pool.getGetTicks(tickLower);
            const upper = await pool.getGetTicks(tickUpper);
        
            expect(lower?.liquidityNet).toBe(liquidity);
            expect(upper?.liquidityNet).toBe(-liquidity);
        });                     
    });
    describe("mint & burn with fees", () => {
        const tickLower = -1000n;
        const tickUpper = 1000n;
        const liquidity = 1n * 10n ** 18n;
    
        beforeEach(async () => {
            await pool.send(
                admin.getSender(),
                { value: toNano("1") },
                {
                    $$type: "Initialize",
                    queryId: 0n,
                    sqrtPriceX96: BigInt(encodeSqrtRatioX96(1, 1).toString())
                }
            );
            await mint(tickLower, tickUpper, liquidity);
        });
    
        it("burn returns liquidity + earned fees", async () => {
            const amountIn = 1000000000000000n; 
            const limit = BigInt(encodeSqrtRatioX96(1, 2).toString());
    
            const swapTx = await pool.send(
                router.getSender(),
                { value: toNano("1") },
                {
                    $$type: "Swap",
                    queryId: 0n,
                    userAddress: user.address,
                    zeroForOne: true,
                    amountSpecified: amountIn,
                    sqrtPriceLimitX96: limit
                }
            );
    
            printTransactionFees(swapTx.transactions);
            console.log(await pool.getGetPoolState())
            console.log((await pool.getGetTicks(tickLower))?.feeGrowthOutside0X128)
            console.log((await pool.getGetTicks(tickLower))?.feeGrowthOutside1X128)
            console.log((await pool.getGetTicks(tickUpper))?.feeGrowthOutside0X128)
            console.log((await pool.getGetTicks(tickUpper))?.feeGrowthOutside1X128)
    
            const burnTx = await pool.send(
                user.getSender(),
                { value: toNano("1") },
                {
                    $$type: "StartBurn",
                    queryId: 1n,
                    index: 0n, 
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    liquidity: liquidity
                }
            );
            printTransactionFees(burnTx.transactions);
    
            const poolState = await pool.getGetPoolState();
            console.log("Pool state after burn:", poolState);
        });
    });
    
});
