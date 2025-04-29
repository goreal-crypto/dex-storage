import { Blockchain, internal, printTransactionFees, SandboxContract, TreasuryContract } from '@ton/sandbox';
import { beginCell, Builder, Dictionary, toNano } from '@ton/core';
import '@ton/test-utils';
import { TickMathTest } from '../build/TickMathTest/tact_TickMathTest';
import { SqrtPriceMathTest } from '../build/SqrtPriceMathTest/tact_SqrtPriceMathTest';
import {Decimal} from "decimal.js";
import { Test } from '../build/Test/tact_Test';
import bn from 'bignumber.js';
import JSBI from 'jsbi';
import invariant from 'tiny-invariant';
import { TickBitmapTest } from '../build/TickBitmapTest/tact_TickBitmapTest';

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
            let amount0 = await sqrtPriceMath.getGetAmount0Delta(BigInt(priceA.toString()), BigInt(priceB.toString()), 0n,)
            expect(amount0).toBe(0n);
        });
        it("1,1 == 2,1 == 0", async () => {
            let priceA = encodeSqrtRatioX96(1,1);
            let priceB = encodeSqrtRatioX96(2,1)
            // console.log(priceA, priceB);
            let amount0 = await sqrtPriceMath.getGetAmount0Delta(BigInt(priceA.toString()), BigInt(priceB.toString()), 0n,)
            expect(amount0).toBe(0n);
        });
        it("1,1 == 121,100 == 90909090909090910n", async () => {
            let priceA = encodeSqrtRatioX96(1,1);
            let priceB = encodeSqrtRatioX96(121,100)
            let liquidity = 10n ** 18n
            // console.log(priceA, priceB);
            let amount0 = await sqrtPriceMath.getGetAmount0Delta(BigInt(priceA.toString()), BigInt(priceB.toString()), liquidity,)
            expect(amount0).toBe(90909090909090910n);
        });
        it("1,1 == 121,100 == -90909090909090909n", async () => {
            let priceA = encodeSqrtRatioX96(1,1);
            let priceB = encodeSqrtRatioX96(121,100)
            let liquidity = -(10n ** 18n)
            // console.log(priceA, priceB);
            let amount0 = await sqrtPriceMath.getGetAmount0Delta(BigInt(priceA.toString()), BigInt(priceB.toString()), liquidity,)
            expect(amount0).toBe(-90909090909090909n);
        });

        it("2^90,1 == 2^96,1 == ?-1?", async () => {
            let priceA = encodeSqrtRatioX96(2 ** 90, 1);
            let priceB = encodeSqrtRatioX96(2 ** 96, 1)
            let liquidity = (10n ** 18n)
            // console.log(priceA, priceB);
            let amount0Up = await sqrtPriceMath.getGetAmount0Delta(BigInt(priceA.toString()), BigInt(priceB.toString()), liquidity,)
            let amount0Down = 1n-await sqrtPriceMath.getGetAmount0Delta(BigInt(priceA.toString()), BigInt(priceB.toString()), -liquidity,)

            expect(amount0Down).toBe(amount0Up);
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
});
