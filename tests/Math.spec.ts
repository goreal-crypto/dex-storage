import { Blockchain, internal, printTransactionFees, SandboxContract, TreasuryContract } from '@ton/sandbox';
import { beginCell, Builder, Dictionary, toNano } from '@ton/core';
import '@ton/test-utils';
import { TickMathTest } from '../build/TickMathTest/tact_TickMathTest';
import { SqrtPriceMathTest } from '../build/SqrtPriceMathTest/tact_SqrtPriceMathTest';
import {Decimal} from "decimal.js";
import { Test } from '../build/Test/tact_Test';
import JSBI from 'jsbi';
import invariant from 'tiny-invariant';
import { TickBitmapTest } from '../build/TickBitmapTest/tact_TickBitmapTest';
import { SwapMathTest } from '../build/SwapMathTest/tact_SwapMathTest';

export const MAX_SAFE_INTEGER = JSBI.BigInt(Number.MAX_SAFE_INTEGER);

const ZERO = JSBI.BigInt(0);
const ONE = JSBI.BigInt(1);
const TWO = JSBI.BigInt(2);

/**
 * Computes floor(sqrt(value))
 * @param value the value for which to compute the square root, rounded down
 */
export function sqrt(value: JSBI): JSBI {
  invariant(JSBI.greaterThanOrEqual(value, ZERO), 'NEGATIVE');

  // rely on built in sqrt if possible
  if (JSBI.lessThan(value, MAX_SAFE_INTEGER)) {
    return JSBI.BigInt(Math.floor(Math.sqrt(JSBI.toNumber(value))));
  }

  let z: JSBI;
  let x: JSBI;
  z = value;
  x = JSBI.add(JSBI.divide(value, TWO), ONE);
  while (JSBI.lessThan(x, z)) {
    z = x;
    x = JSBI.divide(JSBI.add(JSBI.divide(value, x), x), TWO);
  }
  return z;
}

// exports for external consumption
// export type BigintIsh = JSBI | bigint | string
export type BigintIsh = JSBI | number | string;
export function encodeSqrtRatioX96(
    amount1: BigintIsh,
    amount0: BigintIsh
  ): JSBI {
    const numerator = JSBI.leftShift(JSBI.BigInt(amount1), JSBI.BigInt(192));
    const denominator = JSBI.BigInt(amount0);
    const ratioX192 = JSBI.divide(numerator, denominator);
    return sqrt(ratioX192);
  }
describe('test', () => {
    let blockchain: Blockchain;
    let user: SandboxContract<TreasuryContract>;
    let test: SandboxContract<Test>;

    beforeEach(async () => {
        blockchain = await Blockchain.create();
        user = await blockchain.treasury("user");
        test = blockchain.openContract(await Test.fromInit()) 
        await test.send(
            user.getSender(),
            {value: toNano(1)},
            null
        )
    });
    
    it("get next tick", async () => {
        // await blockchain.setVerbosityForAddress(test.address, {
        //     vmLogs: 'vm_logs_full',
        //     print: true,
        //     blockchainLogs: false,
        //     debugLogs: false
        // })

        console.log(await test.getGetNextTick());
    });
});


describe('tickMath', () => {
    let blockchain: Blockchain;
    let user: SandboxContract<TreasuryContract>;
    let tickMathTest: SandboxContract<TickMathTest>;

    beforeEach(async () => {
        blockchain = await Blockchain.create();
        user = await blockchain.treasury("user");
        tickMathTest = blockchain.openContract(await TickMathTest.fromInit()) 
        await tickMathTest.send(
            user.getSender(),
            {value: toNano(1)},
            null
        )
    });
    
    it("get sqrtPrice", async () => {
        expect(await tickMathTest.getGetSqrtRatioAtTick(-887272n)).toEqual(4295128739n);
        expect(await tickMathTest.getGetSqrtRatioAtTick(-887271n)).toEqual(4295343490n);
        expect(await tickMathTest.getGetSqrtRatioAtTick(887271n)).toEqual(1461373636630004318706518188784493106690254656249n);
        expect(await tickMathTest.getGetSqrtRatioAtTick(887272n)).toEqual(1461446703485210103287273052203988822378723970342n);
        for (const absTick of [
            50,
            100,
            250,
            500,
            1_000,
            2_500,
            3_000,
            4_000,
            5_000,
            50_000,
            150_000,
            250_000,
            500_000,
            738_203,
          ]) {
            for (const tick of [-absTick, absTick]) {
                const expected = new Decimal(1.0001).pow(tick).sqrt().mul(new Decimal(2).pow(96));
                const actual = await tickMathTest.getGetSqrtRatioAtTick(BigInt(tick));
                const absDiff = new Decimal(actual.toString()).sub(expected).abs();
                expect(absDiff.div(expected).toNumber()).toBeLessThan(0.000001);
            }
        }
    });

    it("get tick", async () => {
        expect(await tickMathTest.getGetTickAtSqrtRatio(4295128739n)).toEqual(-887272n);
        expect(await tickMathTest.getGetTickAtSqrtRatio(4295343490n)).toEqual(-887271n);
        expect(await tickMathTest.getGetTickAtSqrtRatio(1461373636630004318706518188784493106690254656249n)).toEqual(887271n);
        expect(await tickMathTest.getGetTickAtSqrtRatio(1461446703485210103287273052203988822378723970342n)).toEqual(887272n);
        for (const absTick of [
            50,
            100,
            250,
            500,
            1_000,
            2_500,
            3_000,
            4_000,
            5_000,
            50_000,
            150_000,
            250_000,
            500_000,
            738_203,
          ]) {
            for (const tick of [-absTick, absTick]) {
                const sqrtPrice = await tickMathTest.getGetSqrtRatioAtTick(BigInt(tick));
                expect(await tickMathTest.getGetTickAtSqrtRatio(sqrtPrice)).toEqual(BigInt(tick));
            }
        }
    });
    
});

describe('tickBitmap', () => {
    let blockchain: Blockchain;
    let user: SandboxContract<TreasuryContract>;
    let tickBitmap: SandboxContract<TickBitmapTest>;

    beforeEach(async () => {
        blockchain = await Blockchain.create();
        user = await blockchain.treasury("user");
        tickBitmap = blockchain.openContract(await TickBitmapTest.fromInit()) 
        await tickBitmap.send(
            user.getSender(),
            {value: toNano(1)},
            null
        )
    });
    describe("lte = false", () => {    
        it("78", async () => {
            const nextTick = await tickBitmap.getGetNextInitializedTick(78n, false, 1n);
            expect(nextTick.initialized).toBe(true);
            expect(nextTick.tick).toBe(84n);
        });
        it("-55", async () => {
            const nextTick = await tickBitmap.getGetNextInitializedTick(-55n, false, 1n);
            expect(nextTick.initialized).toBe(true);
            expect(nextTick.tick).toBe(-4n);
        });
        it("77", async () => {
            const nextTick = await tickBitmap.getGetNextInitializedTick(77n, false, 1n);
            expect(nextTick.initialized).toBe(true);
            expect(nextTick.tick).toBe(78n);
        });
        it("-56", async () => {
            const nextTick = await tickBitmap.getGetNextInitializedTick(-56n, false, 1n);
            expect(nextTick.initialized).toBe(true);
            expect(nextTick.tick).toBe(-55n);
        });

        it("255", async () => {
            const nextTick = await tickBitmap.getGetNextInitializedTick(255n, false, 1n);
            expect(nextTick.initialized).toBe(false);
            expect(nextTick.tick).toBe(511n);
        });
        it("-257", async () => {
            const nextTick = await tickBitmap.getGetNextInitializedTick(-257n, false, 1n);
            expect(nextTick.initialized).toBe(true);
            expect(nextTick.tick).toBe(-200n);
        });
        it("340", async () => {
            await tickBitmap.send(
                user.getSender(),
                {value: toNano("0.1")},
                {
                    $$type: "FlipTick",
                    tick: 340n
                }
            )
            const nextTick = await tickBitmap.getGetNextInitializedTick(328n, false, 1n);
            expect(nextTick.initialized).toBe(true);
            expect(nextTick.tick).toBe(340n);
        });
        it("508", async () => {
            const nextTick = await tickBitmap.getGetNextInitializedTick(508n, false, 1n);
            expect(nextTick.tick).toBe(511n);
            expect(nextTick.initialized).toBe(false);
        });
        it("383", async () => {
            const nextTick = await tickBitmap.getGetNextInitializedTick(383n, false, 1n);
            expect(nextTick.tick).toBe(511n);
            expect(nextTick.initialized).toBe(false);
        });
        it("536", async () => {
            const nextTick = await tickBitmap.getGetNextInitializedTick(536n, false, 1n);
            expect(nextTick.tick).toBe(767n);
            expect(nextTick.initialized).toBe(false);
        });
    });
    describe("lte = true", () => {    
        it("78", async () => {
            const nextTick = await tickBitmap.getGetNextInitializedTick(78n, true, 1n);
            expect(nextTick.tick).toBe(78n);
            expect(nextTick.initialized).toBe(true);
        });
        it("79", async () => {
            const nextTick = await tickBitmap.getGetNextInitializedTick(79n, true, 1n);
            expect(nextTick.tick).toBe(78n);
            expect(nextTick.initialized).toBe(true);
        });
        it("258", async () => {
            const nextTick = await tickBitmap.getGetNextInitializedTick(258n, true, 1n);
            expect(nextTick.tick).toBe(256n);
            expect(nextTick.initialized).toBe(false);
        });
        it("256", async () => {
            const nextTick = await tickBitmap.getGetNextInitializedTick(256n, true, 1n);
            expect(nextTick.tick).toBe(256n);
            expect(nextTick.initialized).toBe(false);
        });
        it("72", async () => {
            const nextTick = await tickBitmap.getGetNextInitializedTick(72n, true, 1n);
            expect(nextTick.tick).toBe(70n);
            expect(nextTick.initialized).toBe(true);
        });
        it("-257", async () => {
            const nextTick = await tickBitmap.getGetNextInitializedTick(-257n, true, 1n);
            expect(nextTick.tick).toBe(-512n);
            expect(nextTick.initialized).toBe(false);
        })
        it("1023", async () => {
            const nextTick = await tickBitmap.getGetNextInitializedTick(1023n, true, 1n);
            expect(nextTick.tick).toBe(768n);
            expect(nextTick.initialized).toBe(false);
        });
        it("900", async () => {
            const nextTick = await tickBitmap.getGetNextInitializedTick(900n, true, 1n);
            expect(nextTick.tick).toBe(768n);
            expect(nextTick.initialized).toBe(false);
        });
        it("456", async () => {
            await tickBitmap.send(
                user.getSender(),
                {value: toNano("0.1")},
                {
                    $$type: "FlipTick",
                    tick: 329n
                }
            )
            const nextTick = await tickBitmap.getGetNextInitializedTick(456n, true, 1n);
            expect(nextTick.tick).toBe(329n);
            expect(nextTick.initialized).toBe(true);
        });
    });
});

describe('sqrtPriceMath', () => {
    let blockchain: Blockchain;
    let user: SandboxContract<TreasuryContract>;
    let sqrtPriceMath: SandboxContract<SqrtPriceMathTest>;

    beforeEach(async () => {
        blockchain = await Blockchain.create();
        user = await blockchain.treasury("user");
        sqrtPriceMath = blockchain.openContract(await SqrtPriceMathTest.fromInit()) 
        await sqrtPriceMath.send(
            user.getSender(),
            {value: toNano(1)},
            null
        );
    });
    describe("amount0", () => {
        it("1,1 == 1,1 == 0", async () => {
            let priceA = encodeSqrtRatioX96(1,1);
            let priceB = encodeSqrtRatioX96(1,1)
            // console.log(priceA, priceB);
            let amount0 = await sqrtPriceMath.getgetAmount0Delta_(BigInt(priceA.toString()), BigInt(priceB.toString()), 0n, true)
            expect(amount0).toBe(0n);
        });
        it("1,1 == 2,1 == 0", async () => {
            let priceA = encodeSqrtRatioX96(1,1);
            let priceB = encodeSqrtRatioX96(2,1)
            // console.log(priceA, priceB);
            let amount0 = await sqrtPriceMath.getgetAmount0Delta_(BigInt(priceA.toString()), BigInt(priceB.toString()), 0n, true)
            expect(amount0).toBe(0n);
        });
        it("1,1 == 121,100 == 90909090909090910n", async () => {
            let priceA = encodeSqrtRatioX96(1,1);
            let priceB = encodeSqrtRatioX96(121,100)
            let liquidity = 10n ** 18n
            // console.log(priceA, priceB);
            let amount0 = await sqrtPriceMath.getgetAmount0Delta_(BigInt(priceA.toString()), BigInt(priceB.toString()), liquidity, true)
            expect(amount0).toBe(90909090909090910n);
        });
        it("1,1 == 121,100 == -90909090909090909n", async () => {
            let priceA = encodeSqrtRatioX96(1,1);
            let priceB = encodeSqrtRatioX96(121,100)
            let liquidity = (10n ** 18n)
            // console.log(priceA, priceB);
            let amount0 = await sqrtPriceMath.getgetAmount0Delta_(BigInt(priceA.toString()), BigInt(priceB.toString()), liquidity, false)
            expect(amount0).toBe(90909090909090909n);
        });
        

        it("2^90,1 == 2^96,1 == ?-1?", async () => {
            let priceA = encodeSqrtRatioX96(2 ** 90, 1);
            let priceB = encodeSqrtRatioX96(2 ** 96, 1)
            let liquidity = (10n ** 18n)
            // console.log(priceA, priceB);
            let amount0Up = await sqrtPriceMath.getgetAmount0Delta_(BigInt(priceA.toString()), BigInt(priceB.toString()), liquidity, true)
            let amount0Down = await sqrtPriceMath.getgetAmount0Delta_(BigInt(priceA.toString()), BigInt(priceB.toString()), liquidity, false)

            expect(amount0Up).toBe(amount0Down + 1n);
        });
    });
    describe("amount1", () => {
        it("1,1 == 1,1 == 0", async () => {
            let priceA = encodeSqrtRatioX96(1,1);
            let priceB = encodeSqrtRatioX96(1,1)
            // console.log(priceA, priceB);
            let amount1 = await sqrtPriceMath.getGetAmount1Delta(BigInt(priceA.toString()), BigInt(priceB.toString()), 0n,)
            expect(amount1).toBe(0n);
        });
        it("1,1 == 2,1 == 0", async () => {
            let priceA = encodeSqrtRatioX96(1,1);
            let priceB = encodeSqrtRatioX96(2,1)
            // console.log(priceA, priceB);
            let amount1 = await sqrtPriceMath.getGetAmount1Delta(BigInt(priceA.toString()), BigInt(priceB.toString()), 0n,)
            expect(amount1).toBe(0n);
        });
        it("1,1 == 121,100 == 100000000000000000", async () => {
            let priceA = encodeSqrtRatioX96(1,1);
            let priceB = encodeSqrtRatioX96(121,100)
            let liquidity = 10n ** 18n
            // console.log(priceA, priceB);
            let amount0 = await sqrtPriceMath.getGetAmount1Delta(BigInt(priceA.toString()), BigInt(priceB.toString()), liquidity,)
            expect(amount0).toBe(100000000000000000n);
        });
        it("1,1 == 121,100 == -99999999999999999n", async () => {
            let priceA = encodeSqrtRatioX96(1,1);
            let priceB = encodeSqrtRatioX96(121,100)
            let liquidity = -(10n ** 18n)
            // console.log(priceA, priceB);
            let amount0 = await sqrtPriceMath.getGetAmount1Delta(BigInt(priceA.toString()), BigInt(priceB.toString()), liquidity,)
            expect(amount0).toBe(-99999999999999999n);
        });
    });

    describe("nextSqrtPriceFromInput", () => {
        it("1", async () => {
            const price = 1n
            const liquidity = 1n
            const amountIn = 2n ** 255n
            expect(await sqrtPriceMath.getGetNextSqrtPriceFromInput(price, liquidity, amountIn, true))
            .toBe(1n);
        });
        it("2", async () => {
            const price = BigInt(encodeSqrtRatioX96(1, 1).toString())
            const liquidity = 10n ** 17n
            const amountIn = 0n
            expect(await sqrtPriceMath.getGetNextSqrtPriceFromInput(price, liquidity, amountIn, true))
            .toBe(price);
        });
        it("3", async () => {
            const price = BigInt(encodeSqrtRatioX96(1, 1).toString())
            const liquidity = 10n ** 17n
            const amountIn = 0n
            expect(await sqrtPriceMath.getGetNextSqrtPriceFromInput(price, liquidity, amountIn, false))
            .toBe(price);
        });
        it("4", async () => {
            const price = 1n
            const liquidity = 1n
            const amountIn = 2n ** 255n
            expect(await sqrtPriceMath.getGetNextSqrtPriceFromInput(price, liquidity, amountIn, true))
            .toBe(1n);
        });
        it("5", async () => {
            const price = BigInt(encodeSqrtRatioX96(1, 1).toString())
            const liquidity = 10n ** 17n
            const amountIn = 0n
            expect(await sqrtPriceMath.getGetNextSqrtPriceFromInput(price, liquidity, amountIn, true))
            .toBe(price);
        });
        it("6", async () => {
            const price = BigInt(encodeSqrtRatioX96(1, 1).toString())
            const liquidity = 10n ** 17n
            const amountIn = 0n
            expect(await sqrtPriceMath.getGetNextSqrtPriceFromInput(price, liquidity, amountIn, false))
            .toBe(price);
        });
        // it("7", async () => {
        //     const price = 2n ** 160n - 1n
        //     const liquidity = 2n ** 128n - 1n
        //     const amountIn = 2n ** 256n - 1n - (liquidity << 96n / price)
        //     expect(await sqrtPriceMath.getGetNextSqrtPriceFromInput(price, liquidity, amountIn, true))
        //     .toBe(1n);
        // });
        it("8", async () => {
            const price = BigInt(encodeSqrtRatioX96(1, 1).toString())
            const liquidity = 10n ** 18n
            const amountIn = 10n ** 17n
            expect(await sqrtPriceMath.getGetNextSqrtPriceFromInput(price, liquidity, amountIn, false))
            .toBe(87150978765690771352898345369n);
        });
        it("9", async () => {
            const price = BigInt(encodeSqrtRatioX96(1, 1).toString())
            const liquidity = 10n ** 18n
            const amountIn = 10n ** 17n
            expect(await sqrtPriceMath.getGetNextSqrtPriceFromInput(price, liquidity, amountIn, true))
            .toBe(72025602285694852357767227579n);
        });
        it("10", async () => {
            const price = BigInt(encodeSqrtRatioX96(1, 1).toString())
            const liquidity = 10n ** 19n
            const amountIn = 2n ** 100n
            expect(await sqrtPriceMath.getGetNextSqrtPriceFromInput(price, liquidity, amountIn, true))
            .toBe(624999999995069620n);
        });
        it("11", async () => {
            const price = BigInt(encodeSqrtRatioX96(1, 1).toString())
            const liquidity = 1n
            const amountIn = (2n ** 128n - 1n)
            console.log("11");
            expect(await sqrtPriceMath.getGetNextSqrtPriceFromInput(price, liquidity, amountIn, true))
            .toBe(1n);
        });
    });
    describe("nextSqrtPriceFromOutput", () => {
        it("1", async () => {
            const price = 20282409603651670423947251286016n
            const liquidity = 1024n
            const amountOut = 262143n
            expect(await sqrtPriceMath.getGetNextSqrtPriceFromOutput(price, liquidity, amountOut, true))
            .toBe(77371252455336267181195264n);
        });
        it("2", async () => {
            const price = BigInt(encodeSqrtRatioX96(1, 1).toString())
            const liquidity = 10n ** 17n
            const amountOut = 0n
            expect(await sqrtPriceMath.getGetNextSqrtPriceFromOutput(price, liquidity, amountOut, false))
            .toBe(price);
        });
        it("3", async () => {
            const price = BigInt(encodeSqrtRatioX96(1, 1).toString())
            const liquidity = 10n ** 17n
            const amountOut = 0n
            expect(await sqrtPriceMath.getGetNextSqrtPriceFromOutput(price, liquidity, amountOut, true))
            .toBe(price);
        });
        it("4", async () => {
            const price = BigInt(encodeSqrtRatioX96(1, 1).toString())
            const liquidity = 10n ** 18n
            const amountOut = 10n ** 17n
            expect(await sqrtPriceMath.getGetNextSqrtPriceFromOutput(price, liquidity, amountOut, false))
            .toBe(88031291682515930659493278152n);
        });
        it("5", async () => {
            const price = BigInt(encodeSqrtRatioX96(1, 1).toString())
            const liquidity = 10n ** 18n
            const amountOut = 10n ** 17n
            expect(await sqrtPriceMath.getGetNextSqrtPriceFromOutput(price, liquidity, amountOut, true))
            .toBe(71305346262837903834189555302n);
        });
    });
});

describe('swapMath', () => {
    let blockchain: Blockchain;
    let user: SandboxContract<TreasuryContract>;
    let swapMath: SandboxContract<SwapMathTest>;

    beforeEach(async () => {
        blockchain = await Blockchain.create();
        user = await blockchain.treasury("user");
        swapMath = blockchain.openContract(await SwapMathTest.fromInit()) 
        await swapMath.send(
            user.getSender(),
            {value: toNano(1)},
            null
        )
    });

    it("1", async () => {
        const price = BigInt(encodeSqrtRatioX96(1, 1).toString())
        const priceTarget = BigInt(encodeSqrtRatioX96(101, 100).toString())
        const liquidity = 2n * (10n ** 18n)
        const amount = (10n ** 18n)
        const zeroForOne = false
        const fee = 600n
        const swapStep = await swapMath.getGetComputeSwapStep(price, priceTarget, liquidity, amount, fee);
        expect(swapStep.amountIn).toBe(9975124224178055n);
        expect(swapStep.amountOut).toBe(9925619580021728n);
        expect(swapStep.feeAmount).toBe(5988667735148n);
        expect(swapStep.amountIn + swapStep.feeAmount).toBeLessThan(amount);
        expect(swapStep.sqrtRatioNextX96).toBe(priceTarget);
    });
    it("2", async () => {
        const price = BigInt(encodeSqrtRatioX96(1, 1).toString())
        const priceTarget = BigInt(encodeSqrtRatioX96(101, 100).toString())
        const liquidity = 2n * (10n ** 18n)
        const amount = -(10n ** 18n)
        const zeroForOne = false
        const fee = 600n
        const swapStep = await swapMath.getGetComputeSwapStep(price, priceTarget, liquidity, amount, fee);
        expect(swapStep.amountIn).toBe(9975124224178055n);
        expect(swapStep.amountOut).toBe(9925619580021728n);
        expect(swapStep.feeAmount).toBe(5988667735148n);
        expect(swapStep.amountOut).toBeLessThan(-amount);
        expect(swapStep.sqrtRatioNextX96).toBe(priceTarget);
    });
    // it("3", async () => {
    //     console.log(3)
    //     const price = BigInt(encodeSqrtRatioX96(1, 1).toString())
    //     console.log(price);
    //     const priceTarget = BigInt(encodeSqrtRatioX96(1000, 100).toString())
    //     console.log(priceTarget)
    //     console.log(price > priceTarget)
    //     const liquidity = 2n * (10n ** 18n)
    //     const amount = (10n ** 18n)
    //     const zeroForOne = false
    //     const fee = 600n
    //     const swapStep = await swapMath.getGetComputeSwapStep(price, priceTarget, liquidity, amount, fee);
    //     // expect(swapStep.amountOut).toBe(999400000000000000n);
    //     // expect(swapStep.amountIn).toBe(666399946655997866n);
    //     expect(swapStep.feeAmount).toBe(600000000000000n);
    //     expect(swapStep.amountOut + swapStep.feeAmount).toBe(amount);
    //     expect(swapStep.sqrtRatioNextX96).toBeLessThan(priceTarget);
    // });
    it("4", async () => {
        console.log(4)
        const price = BigInt(encodeSqrtRatioX96(1, 1).toString())
        console.log(price);
        const priceTarget = BigInt(encodeSqrtRatioX96(10000, 100).toString())
        console.log(priceTarget)
        console.log(price > priceTarget)
        const liquidity = 2n * (10n ** 18n)
        const amount = -(10n ** 18n)
        const zeroForOne = false
        const fee = 600n
        const swapStep = await swapMath.getGetComputeSwapStep(price, priceTarget, liquidity, amount, fee);
        expect(swapStep.amountIn).toBe(2000000000000000000n);
        expect(swapStep.amountOut).toBe(-amount);
        expect(swapStep.feeAmount).toBe(1200720432259356n);
        expect(swapStep.sqrtRatioNextX96).toBeLessThan(priceTarget);
    });
    it("5", async () => {
        console.log(5)
        const price = 417332158212080721273783715441582n
        console.log(price);
        const priceTarget = 1452870262520218020823638996n
        console.log(priceTarget)
        console.log(price > priceTarget)
        const liquidity = 159344665391607089467575320103n
        const amount = -1n
        const zeroForOne = false
        const fee = 1n
        const swapStep = await swapMath.getGetComputeSwapStep(price, priceTarget, liquidity, amount, fee);
        expect(swapStep.amountIn).toBe(1n);
        expect(swapStep.amountOut).toBe(1n);
        expect(swapStep.feeAmount).toBe(1n);
        expect(swapStep.sqrtRatioNextX96).toBe(417332158212080721273783715441581n);
    });
    it("6", async () => {
        console.log(6)
        const price = 2n
        console.log(price);
        const priceTarget = 1n
        console.log(priceTarget)
        console.log(price > priceTarget)
        const liquidity = 1n
        const amount = 3915081100057732413702495386755767n
        const zeroForOne = false
        const fee = 1n
        const swapStep = await swapMath.getGetComputeSwapStep(price, priceTarget, liquidity, amount, fee);
        expect(swapStep.amountIn).toBe(39614081257132168796771975168n);
        expect(swapStep.amountOut).toBe(0n);
        expect(swapStep.feeAmount).toBe(39614120871253040049813n);
        expect(swapStep.sqrtRatioNextX96).toBe(1n);
    });
    // it("7", async () => {
    //     console.log(7)
    //     const price = 2413n
    //     console.log(price);
    //     const priceTarget = 79887613182836312n
    //     console.log(priceTarget)
    //     console.log(price > priceTarget)
    //     const liquidity = 1985041575832132834610021537970n
    //     const amount = 10n
    //     const zeroForOne = false
    //     const fee = 1872n
    //     const swapStep = await swapMath.getGetComputeSwapStep(price, priceTarget, liquidity, amount, fee);
    //     // expect(swapStep.amountIn).toBe(0n);
    //     // expect(swapStep.amountOut).toBe(0n);
    //     expect(swapStep.feeAmount).toBe(10n);
    //     expect(swapStep.sqrtRatioNextX96).toBe(2413n);
    // });
    it("8", async () => {
        console.log(8)
        const price = 20282409603651670423947251286016n
        console.log(price);
        const priceTarget = price * 11n / 10n
        console.log(priceTarget)
        console.log(price > priceTarget)
        const liquidity = 1024n
        const amount = -4n
        const zeroForOne = false
        const fee = 3000n
        const swapStep = await swapMath.getGetComputeSwapStep(price, priceTarget, liquidity, amount, fee);
        expect(swapStep.amountIn).toBe(26215n);
        expect(swapStep.amountOut).toBe(0n);
        expect(swapStep.feeAmount).toBe(79n);
        expect(swapStep.sqrtRatioNextX96).toBe(priceTarget);
    });
    it("9", async () => {
        console.log(9)
        const price = 20282409603651670423947251286016n
        console.log(price);
        const priceTarget = price * 9n / 10n
        console.log(priceTarget)
        console.log(price > priceTarget)
        const liquidity = 1024n
        const amount = -263000n
        const zeroForOne = false
        const fee = 3000n
        const swapStep = await swapMath.getGetComputeSwapStep(price, priceTarget, liquidity, amount, fee);
        expect(swapStep.amountIn).toBe(1n);
        expect(swapStep.amountOut).toBe(26214n);
        expect(swapStep.feeAmount).toBe(1n);
        expect(swapStep.sqrtRatioNextX96).toBe(priceTarget);
    });
});