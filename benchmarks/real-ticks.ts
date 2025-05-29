import { Blockchain, printTransactionFees } from "@ton/sandbox";
import { Pool } from "../build/V3Pool/tact_Pool";
import { Dictionary, toNano } from "@ton/core";
import { encodeSqrtRatioX96 } from "../utils/math";
import { getUsedGasInternal } from "../utils/gas";
import { TickMathTest } from "../build/TickMathTest/tact_TickMathTest";
import { randomInt } from "crypto"; 

const main = async () => {
    const NUM_SAMPLES = 50; 
    const TICK_SPACING = 256n; 
    const MAX_TICKS = 30; 
    let liquidity = 10n ** 12n;
    let results: {mean: number[], variance: number[]} = {
        mean: [],
        variance: []
    };
    for (let numRanges = 1; numRanges <= MAX_TICKS; numRanges++) {
        let gasResults: number[] = [];

        for (let sample = 0; sample < NUM_SAMPLES; sample++) {
            if (sample % 10 == 0) console.log(sample);
            let blockchain = await Blockchain.create();
            let user = await blockchain.treasury("user_");
            let admin = await blockchain.treasury("admin_)");
            let router = await blockchain.treasury("router_");
            let token0 = await blockchain.treasury("token0Address_");
            let token1 = await blockchain.treasury("token1Address_");
            
            let pool = blockchain.openContract(await Pool.fromInit(
                router.address,
                token0.address,
                token1.address,
                0n,
                0n,
                0n,
                {$$type: "TicksMap", data: Dictionary.empty()},
                1n,
                0n,
                0n,
                0n,
                0n
            ));

            let tickMathTest = blockchain.openContract(await TickMathTest.fromInit());
            await tickMathTest.send(
                user.getSender(),
                {value: toNano(1)},
                null
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
            };

            const deploy = await pool.send(
                admin.getSender(),
                {value: toNano("1")},
                {
                    $$type: "Initialize",
                    queryId: 0n,
                    sqrtPriceX96: BigInt(encodeSqrtRatioX96(1,1).toString())
                }
            );

            for (let range = 0; range < numRanges; range++) {
                const baseTick = range * Number(TICK_SPACING);
                const randOffset = BigInt(randomInt(0, 20)); 
                const tickLower = BigInt(baseTick);
                const tickUpper = BigInt(baseTick) + TICK_SPACING - randOffset;
                
                await mint(tickLower, tickUpper, liquidity);
            }

            const lastRangeUpper = (numRanges - 1) * Number(TICK_SPACING);
            const swap = await pool.send(
                router.getSender(),
                {value: toNano("1")},
                {
                    $$type: "Swap",
                    queryId: 0n,
                    userAddress: user.address,
                    zeroForOne: false,
                    amountSpecified: 10n ** 18n,
                    sqrtPriceLimitX96: await tickMathTest.getGetSqrtRatioAtTick(BigInt(lastRangeUpper))
                }
            );

            gasResults.push(getUsedGasInternal(swap, {type: "chain"}));
        }

        const mean = gasResults.reduce((a, b) => a + b, 0) / NUM_SAMPLES;
        const variance = gasResults.reduce((sq, n) => sq + Math.pow(n - mean, 2), 0) / NUM_SAMPLES;
        
        results.mean.push(mean);
        results.variance.push(variance);
        
        console.log(`Ranges: ${numRanges}, Mean gas: ${mean}, Variance: ${variance}`);
    }
    console.log("Final results:", results);
};

void main()