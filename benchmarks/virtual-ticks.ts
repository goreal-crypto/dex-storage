import { Blockchain } from "@ton/sandbox";
import { Pool } from "../build/V3Pool/tact_Pool";
import { Dictionary, toNano } from "@ton/core";
import { encodeSqrtRatioX96 } from "../utils/math";
import { getUsedGasInternal } from "../utils/gas";
import { TickMathTest } from "../build/TickMathTest/tact_TickMathTest";

const main = async () => {
    const NUM_SAMPLES = 5;
    const TICK_SPACING = 1n;
    const MIN_TICK = -8000n;
    const MAX_TICK = 8000n;
    const INITIAL_LIQUIDITY = 10n ** 12n;
    const SWAP_AMOUNT = 10n ** 18n;
    const BASE_TICK = 256n;
    const MAX_CROSSED_TICKS = 30;

    const results: number[] = [];

    for (let i = 1; i <= MAX_CROSSED_TICKS; i++) {
        const targetTick = BASE_TICK * BigInt(i);
        let gasResults: number[] = [];

        for (let sample = 0; sample < NUM_SAMPLES; sample++) {
            // Инициализация нового блокчейна для каждого теста
            const blockchain = await Blockchain.create();
            const user = await blockchain.treasury("user");
            const admin = await blockchain.treasury("admin");
            const router = await blockchain.treasury("router");
            const token0 = await blockchain.treasury("token0");
            const token1 = await blockchain.treasury("token1");

            // Создание и инициализация пула
            const pool = blockchain.openContract(await Pool.fromInit(
                router.address,
                token0.address,
                token1.address,
                0n,
                0n,
                0n,
                {$$type: "TicksMap", data: Dictionary.empty()},
                TICK_SPACING,
                0n,
                0n,
                0n,
                0n
            ));

            const tickMathTest = blockchain.openContract(await TickMathTest.fromInit());
            await tickMathTest.send(user.getSender(), {value: toNano("1")}, null);
            // Инициализация пула с начальной ценой (в центре первого диапазона)
            const initialSqrtPrice = await tickMathTest.getGetSqrtRatioAtTick(MIN_TICK + TICK_SPACING/2n);
            await pool.send(admin.getSender(), {value: toNano("1")}, {
                $$type: "Initialize",
                queryId: 0n,
                sqrtPriceX96: initialSqrtPrice
            });
            // Добавление ликвидности от MIN_TICK до MAX_TICK
            const mintLiquidity = async (tickLower: bigint, tickUpper: bigint) => {
                const amounts = await pool.getGetMintEstimate(tickLower, tickUpper, INITIAL_LIQUIDITY);
                await pool.send(router.getSender(), {value: toNano("1")}, {
                    $$type: "ProvideLiquidity",
                    queryId: 0n,
                    userAddress: user.address,
                    amount0: amounts.amount0,
                    amount1: amounts.amount1,
                    enough0: amounts.amount0,
                    enough1: amounts.amount1,
                    liquidity: INITIAL_LIQUIDITY,
                    tickLower: tickLower,
                    tickUpper: tickUpper
                });
            };

            // Создаем один большой диапазон ликвидности
            await mintLiquidity(MIN_TICK, MAX_TICK);

            

            // Выполняем свап до targetTick
            const targetSqrtPrice = await tickMathTest.getGetSqrtRatioAtTick(targetTick);
            const swapResult = await pool.send(
                router.getSender(),
                {value: toNano("1")},
                {
                    $$type: "Swap",
                    queryId: 0n,
                    userAddress: user.address,
                    zeroForOne: false,
                    amountSpecified: SWAP_AMOUNT,
                    sqrtPriceLimitX96: targetSqrtPrice
                }
            );

            gasResults.push(getUsedGasInternal(swapResult, {type: "chain"}));
        }

        const meanGas = gasResults.reduce((sum, gas) => sum + gas, 0) / gasResults.length;
        results.push(meanGas);

        console.log(`Ticks crossed: ${i} (target tick: ${targetTick}), Mean gas: ${meanGas}`);
    }

    console.log("Final results:", JSON.stringify(results, null, 2));
};

void main();