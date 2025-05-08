import { Blockchain } from "@ton/sandbox";
import { Pool } from "../build/V3Pool/tact_Pool";
import { Dictionary, toNano } from "@ton/core";
import { encodeSqrtRatioX96 } from "../utils/math";
import { getUsedGasInternal } from "../utils/gas";

export async function run() {
    const liquidityConfigs = [
        {tickLower: 0n, tickUpper: 100n},
        {tickLower: 100n, tickUpper: 200n},
        {tickLower: 200n, tickUpper: 300n},
        {tickLower: 300n, tickUpper: 400n},
        {tickLower: 400n, tickUpper: 500n},
        {tickLower: 500n, tickUpper: 600n},
        {tickLower: 600n, tickUpper: 700n},
        {tickLower: 700n, tickUpper: 800n},
        {tickLower: 800n, tickUpper: 900n},
    ];

    let liquidity = 10n ** 10n;
    for (let i = 1; i <= liquidityConfigs.length; i++) {
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
                    Dictionary.empty(),
                    1n,
                    0n
        ));
        const mint = async (tickLower: bigint, tickUpper: bigint, liquidity: bigint)  => {
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
        const deploy = await pool.send(
            admin.getSender(),
            {value: toNano("1")},
            {
                $$type: "Initialize",
                queryId: 0n,
                sqrtPriceX96: BigInt(encodeSqrtRatioX96(1,1).toString())
            }
        )  
        for (let j = 0; j < i; j++) {
            mint(liquidityConfigs[j].tickLower, liquidityConfigs[j].tickUpper, liquidity);
        }
        const swap = await pool.send(
            router.getSender(),
            {value: toNano("1")},
            {
                $$type: "Swap",
                queryId: 0n,
                userAddress: user.address,
                zeroForOne: true,
                amountSpecified: 500000000000n,
                sqrtPriceLimitX96: BigInt(encodeSqrtRatioX96(1,2).toString())
            }
        );

        console.log(await pool.getGetPoolState());
        console.log(getUsedGasInternal(swap, {type: "chain"}))
    }
}
