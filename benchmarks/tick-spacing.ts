import { Blockchain } from "@ton/sandbox";
import { Pool } from "../build/V3Pool/tact_Pool";
import { Dictionary, toNano } from "@ton/core";
import { encodeSqrtRatioX96 } from "../utils/math";
import { getUsedGasInternal } from "../utils/gas";
import { randomInt } from "crypto";

// Конфигурация теста
const CONFIG = {
    NUM_SAMPLES: 5, // Уменьшено для демонстрации
    MAX_TICKS: 30,
    TICK_SPACINGS: [1, 3, 5, 10, 50, 100] // Добавлены разные значения tickSpacing
};

interface GasResults {
    [tickSpacing: number]: number[]
}

const main = async () => {
    const results: GasResults = {};
    
    for (const TICK_SPACING of CONFIG.TICK_SPACINGS) {
        console.log(`\n=== Testing tickSpacing: ${TICK_SPACING} ===`);
        const tickResults: number[] = [];

        for (let numRanges = 1; numRanges <= CONFIG.MAX_TICKS; numRanges++) {
            const gasResults: number[] = [];
            console.log(`Processing ${numRanges} ranges...`);

                const blockchain = await Blockchain.create();
                const user = await blockchain.treasury("user");
                const admin = await blockchain.treasury("admin");
                const router = await blockchain.treasury("router");
                const token0 = await blockchain.treasury("token0");
                const token1 = await blockchain.treasury("token1");

                // Инициализация пула с текущим tickSpacing
                const pool = blockchain.openContract(await Pool.fromInit(
                    router.address,
                    token0.address,
                    token1.address,
                    0n,
                    0n,
                    0n,
                    { $$type: "TicksMap", data: Dictionary.empty() },
                    BigInt(TICK_SPACING), // Используем текущее tickSpacing
                    0n,
                    0n,
                    0n,
                    100n // 1% fee
                ));

                // Деплой и инициализация
                await pool.send(
                    admin.getSender(),
                    { value: toNano("1") },
                    {
                        $$type: "Initialize",
                        queryId: 0n,
                        sqrtPriceX96: BigInt(encodeSqrtRatioX96(1, 1).toString())
                    }
                );
                const mint = async (tickLower: bigint, tickUpper: bigint, liquidity: bigint) => {
                    const amounts = await pool.getGetMintEstimate(tickLower, tickUpper, liquidity);
                    const send1 = await pool.send(
                        router.getSender(),
                        {value: toNano("1")},
                        {
                            $$type: "ProvideLiquidity",
                            queryId: 0n,
                            userAddress: user.address,
                            amount0: 0n,
                            amount1: amounts.amount1,
                            enough0: amounts.amount0,
                            enough1: amounts.amount1,
                            liquidity: liquidity,
                            tickLower: tickLower,
                            tickUpper: tickUpper
                        }
                    );
                    const send2 = await pool.send(
                        router.getSender(),
                        {value: toNano("1")},
                        {
                            $$type: "ProvideLiquidity",
                            queryId: 0n,
                            userAddress: user.address,
                            amount0: amounts.amount0,
                            amount1: 0n,
                            enough0: amounts.amount0,
                            enough1: amounts.amount1,
                            liquidity: liquidity,
                            tickLower: tickLower,
                            tickUpper: tickUpper
                        }
                    );
                }
                // Добавление ликвидности
                for (let range = 0; range < numRanges; range++) {
                    const baseTick = range * 600;
                    const tickLower = BigInt(baseTick);
                    const tickUpper = BigInt(baseTick + 100);
                    
                    mint(tickLower, tickUpper, 10n ** 18n)
                }

                // Выполнение swap
                const swapTx = await pool.send(
                    router.getSender(),
                    { value: toNano("1") },
                    {
                        $$type: "Swap",
                        queryId: 0n,
                        userAddress: user.address,
                        zeroForOne: false,
                        amountSpecified: 10n ** 18n,
                        sqrtPriceLimitX96: BigInt(encodeSqrtRatioX96(100, 1).toString())
                    }
                );

                tickResults.push(getUsedGasInternal(swapTx, {type: "chain"}));
            }

        results[TICK_SPACING] = tickResults;
        console.log(`Results for tickSpacing ${TICK_SPACING}:`, JSON.stringify(tickResults));
    }

    // Финализация вывода
    console.log("\nFinal Results:");
    console.log(JSON.stringify(results, null, 2));
};

void main();