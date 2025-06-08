import { Blockchain } from "@ton/sandbox";
import { Pool } from "../build/V3Pool/tact_Pool";
import { Dictionary, toNano } from "@ton/core";
import { encodeSqrtRatioX96 } from "../utils/math";
import { getUsedGasInternal } from "../utils/gas";

const NUM_RANGES = 10;
const MAX_TICK_SPACING = 50;

const main = async () => {
    const results: { [tickSpacing: number]: number } = {};

    for (let tickSpacing = 1; tickSpacing <= MAX_TICK_SPACING; tickSpacing++) {
        console.log(`\n=== Testing tickSpacing: ${tickSpacing} ===`);

        const blockchain = await Blockchain.create();
        const user = await blockchain.treasury("user");
        const admin = await blockchain.treasury("admin");
        const router = await blockchain.treasury("router");
        const token0 = await blockchain.treasury("token0");
        const token1 = await blockchain.treasury("token1");

        const pool = blockchain.openContract(await Pool.fromInit(
            router.address,
            token0.address,
            token1.address,
            0n,
            0n,
            0n,
            { $$type: "TicksMap", data: Dictionary.empty() },
            BigInt(tickSpacing),
            0n,
            0n,
            0n,
            100n 
        ));

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
        };
        const tickLower = -1000n * BigInt(tickSpacing);
        const tickUpper = 1000n * BigInt(tickSpacing);

        await mint(tickLower, tickUpper, 10n ** 10n);
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

        const gasUsed = getUsedGasInternal(swapTx, { type: "chain" });
        results[tickSpacing] = gasUsed;

        console.log(`tickSpacing: ${tickSpacing}, gasUsed: ${gasUsed}`);
    }

    console.log("\nFinal results:");
    console.log(JSON.stringify(results, null, 2));
};

void main();
