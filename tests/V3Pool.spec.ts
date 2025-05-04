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
            0n
        ));
    });

    it("initialize", async () => {
        const deploy = await pool.send(
            admin.getSender(),
            {value: toNano("1")},
            {
                $$type: "Initialize",
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
                    sqrtPriceX96: BigInt(encodeSqrtRatioX96(1,1).toString())
                }
            )   
            const amounts = await pool.getGetMintEstimate(BigInt(getMinTick(60)), BigInt(getMaxTick(60)), 3161n);
            console.log(amounts)
        });  
        it("1", async () => {
            const liquidity = 2n * (10n ** 18n)
            const amounts = await pool.getGetMintEstimate(-22980n, 0n, liquidity)
            const send1 = await pool.send(
                router.getSender(),
                {value: toNano("1")},
                {
                    $$type: "ProvideLiquidity",
                    userAddress: user.address,
                    amount0: 0n,
                    amount1: amounts.amount1,
                    enough0: amounts.amount0,
                    enough1: amounts.amount1,
                    liquidity: liquidity,
                    tickLower: -22980n,
                    tickUpper: 0n
                }
            );
            const send2 = await pool.send(
                router.getSender(),
                {value: toNano("1")},
                {
                    $$type: "ProvideLiquidity",
                    userAddress: user.address,
                    amount0: amounts.amount0,
                    amount1: 0n,
                    enough0: amounts.amount0,
                    enough1: amounts.amount1,
                    liquidity: liquidity,
                    tickLower: -22980n,
                    tickUpper: 0n
                }
            );

            const state = await pool.getGetPoolState();
            console.log(state);
            
            printTransactionFees(send2.transactions);
        });

        it("2", async () => {
            const liquidity1 = 2n * (10n ** 18n)
            console.log(await pool.getGetPoolState());
            const amounts1 = await pool.getGetMintEstimate(-8000n, 8000n, liquidity1);
            const mint1A = await pool.send(
                router.getSender(),
                {value: toNano("1")},
                {
                    $$type: "ProvideLiquidity",
                    userAddress: user.address,
                    amount0: 0n,
                    amount1: amounts1.amount1,
                    enough0: amounts1.amount0,
                    enough1: amounts1.amount1,
                    liquidity: liquidity1,
                    tickLower: -8000n,
                    tickUpper: 8000n
                }
            );
            const mint1B = await pool.send(
                router.getSender(),
                {value: toNano("1")},
                {
                    $$type: "ProvideLiquidity",
                    userAddress: user.address,
                    amount0: amounts1.amount0,
                    amount1: 0n,
                    enough0: amounts1.amount0,
                    enough1: amounts1.amount1,
                    liquidity: liquidity1,
                    tickLower: -8000n,
                    tickUpper: 8000n
                }
            );
            console.log(await pool.getGetPoolState());


            const liquidity2 = 2n * (10n ** 18n)

            const amounts2 = await pool.getGetMintEstimate(-200n, 200n, liquidity2);
            const mint2A = await pool.send(
                router.getSender(),
                {value: toNano("1")},
                {
                    $$type: "ProvideLiquidity",
                    userAddress: user.address,
                    amount0: 0n,
                    amount1: amounts2.amount1,
                    enough0: amounts2.amount0,
                    enough1: amounts2.amount1,
                    liquidity: liquidity2,
                    tickLower: -200n,
                    tickUpper: 200n
                }
            );
            const mint2B = await pool.send(
                router.getSender(),
                {value: toNano("1")},
                {
                    $$type: "ProvideLiquidity",
                    userAddress: user.address,
                    amount0: amounts2.amount0,
                    amount1: 0n,
                    enough0: amounts2.amount0,
                    enough1: amounts2.amount1,
                    liquidity: liquidity2,
                    tickLower: -200n,
                    tickUpper: 200n
                }
            );
            console.log(amounts2)
            const state = await pool.getGetPoolState();
            console.log(state.ticks.get(-200)?.liquidityNet);
            console.log(state.ticks.get(200)?.liquidityNet);
            console.log(state.ticks.get(-8000)?.liquidityNet);
            console.log(state.ticks.get(8000)?.liquidityNet);

            
            const swap = await pool.send(
                router.getSender(),
                {value: toNano("10")},
                {$$type: "Swap",
                    userAddress: user.address,
                    zeroForOne: true,
                    amountSpecified: 500000000000000000n,
                    sqrtPriceLimitX96: BigInt(encodeSqrtRatioX96(1, 2).toString()),
                }
            );

            printTransactionFees(swap.transactions);
            console.log(await pool.getGetPoolState())
            
        });

    });

    describe("ticks", () => {
        let tickMathTest: SandboxContract<TickMathTest>;
        beforeEach(async () => {
            tickMathTest = blockchain.openContract(await TickMathTest.fromInit()) 
            await tickMathTest.send(
                user.getSender(),
                {value: toNano(1)},
                null
            )
            const deploy = await pool.send(
                admin.getSender(),
                {value: toNano("1")},
                {
                    $$type: "Initialize",
                    sqrtPriceX96: BigInt(encodeSqrtRatioX96(1,1).toString())
                }
            )  

            const liquidity1 = 2n * (10n ** 18n)
            console.log(await pool.getGetPoolState());
            const amounts1 = await pool.getGetMintEstimate(-8000n, 8000n, liquidity1);
            const mint1A = await pool.send(
                router.getSender(),
                {value: toNano("1")},
                {
                    $$type: "ProvideLiquidity",
                    userAddress: user.address,
                    amount0: 0n,
                    amount1: amounts1.amount1,
                    enough0: amounts1.amount0,
                    enough1: amounts1.amount1,
                    liquidity: liquidity1,
                    tickLower: -8000n,
                    tickUpper: 8000n
                }
            );
            const mint1B = await pool.send(
                router.getSender(),
                {value: toNano("1")},
                {
                    $$type: "ProvideLiquidity",
                    userAddress: user.address,
                    amount0: amounts1.amount0,
                    amount1: 0n,
                    enough0: amounts1.amount0,
                    enough1: amounts1.amount1,
                    liquidity: liquidity1,
                    tickLower: -8000n,
                    tickUpper: 8000n
                }
            );
            console.log(await pool.getGetPoolState());


            const liquidity2 = 2n * (10n ** 18n)

            const amounts2 = await pool.getGetMintEstimate(-200n, 200n, liquidity2);
            const mint2A = await pool.send(
                router.getSender(),
                {value: toNano("1")},
                {
                    $$type: "ProvideLiquidity",
                    userAddress: user.address,
                    amount0: 0n,
                    amount1: amounts2.amount1,
                    enough0: amounts2.amount0,
                    enough1: amounts2.amount1,
                    liquidity: liquidity2,
                    tickLower: -200n,
                    tickUpper: 200n
                }
            );
            const mint2B = await pool.send(
                router.getSender(),
                {value: toNano("1")},
                {
                    $$type: "ProvideLiquidity",
                    userAddress: user.address,
                    amount0: amounts2.amount0,
                    amount1: 0n,
                    enough0: amounts2.amount0,
                    enough1: amounts2.amount1,
                    liquidity: liquidity2,
                    tickLower: -200n,
                    tickUpper: 200n
                }
            );
            console.log(amounts2)
            const state = await pool.getGetPoolState();
            console.log(state.ticks.get(-200)?.liquidityNet);
            console.log(state.ticks.get(200)?.liquidityNet);
            console.log(state.ticks.get(-8000)?.liquidityNet);
            console.log(state.ticks.get(8000)?.liquidityNet);

            
        });
        
        let res: number[] = []
        for (let i = 0; i < 5000; i+=256) {
            it(i.toString(), async () => {
                let sqrtPriceLimitX96 = await tickMathTest.getGetSqrtRatioAtTick(BigInt(i));
            
                
                const swap = await pool.send(
                    router.getSender(),
                    {value: toNano("10")},
                    {$$type: "Swap",
                        userAddress: user.address,
                        zeroForOne: false,
                        amountSpecified: 500000000000000000n,
                        sqrtPriceLimitX96: sqrtPriceLimitX96,
                    }
                );
                res.push(getUsedGasInternal(swap, {type: "chain"}))
                printTransactionFees(swap.transactions);
                console.log(await pool.getGetPoolState())
                console.log(res);

            });
        }
    })
});
