import { Blockchain, printTransactionFees } from "@ton/sandbox";
import { Pool } from "../build/V3Pool/tact_Pool";
import { Dictionary, toNano } from "@ton/core";
import { encodeSqrtRatioX96 } from "../utils/math";
import { getUsedGasInternal } from "../utils/gas";
import { TickMathTest } from "../build/TickMathTest/tact_TickMathTest";
import { randomInt } from "crypto"; 

const main = async () => {
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
        // Dictionary.empty(),
        1n,
        0n,
        0n,
        0n,
        0n
    ));
    const deploy = await pool.send(
        admin.getSender(),
        {value: toNano("1")},
        {
            $$type: "Initialize",
            queryId: 0n,
            sqrtPriceX96: BigInt(encodeSqrtRatioX96(1,1).toString())
        }
    );

    let tickLower = -1000n;
    let tickUpper = 1000n;
    let liquidity = 10n ** 18n;
    const amounts = await pool.getGetMintEstimate(tickLower, tickUpper, liquidity);
    const mint1 = await pool.send(
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
    const mint2 = await pool.send(
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
    printTransactionFees(mint2.transactions)
    console.log("MINT GAS: ", getUsedGasInternal(mint1, {type: "chain"}) + getUsedGasInternal(mint2, {type: "chain"}))
    const swap = await pool.send(
        router.getSender(),
        {value: toNano("1")},
        {
            $$type: "Swap",
            queryId: 0n,
            userAddress: user.address,
            zeroForOne: true,
            amountSpecified: 500n,
            sqrtPriceLimitX96: BigInt(encodeSqrtRatioX96(1,2).toString())
        }
    );
    printTransactionFees(swap.transactions);
    console.log("SWAP GAS: ", getUsedGasInternal(swap, {type: "chain"}))
    const burn = await pool.send(
        user.getSender(),
        {value: toNano("1")},
        {
            $$type: "StartBurn",
            queryId: 0n,
            tickLower: tickLower,
            tickUpper: tickUpper,
            index: 0n,
            liquidity: liquidity
        }
    );
    printTransactionFees(burn.transactions)
    console.log("BURN GAS: ", getUsedGasInternal(burn, {type: "chain"}))
};

void main()