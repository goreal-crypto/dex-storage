import { Blockchain, internal, printTransactionFees, SandboxContract, TreasuryContract } from '@ton/sandbox';
import { beginCell, Builder, toNano } from '@ton/core';
import '@ton/test-utils';
import {Test} from '../build/Test/tact_Test';
import {Decimal} from "decimal.js";


describe('CLAMM Math test', () => {
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

    it("sqrtPrice", async () => {
        expect(await test.getGetSqrtPriceAtTick(-887272n)).toEqual(4295128739n);
        expect(await test.getGetSqrtPriceAtTick(-887271n)).toEqual(4295343490n);
        expect(await test.getGetSqrtPriceAtTick(887271n)).toEqual(1461373636630004318706518188784493106690254656249n);
        expect(await test.getGetSqrtPriceAtTick(887272n)).toEqual(1461446703485210103287273052203988822378723970342n);
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
                const actual = await test.getGetSqrtPriceAtTick(BigInt(tick));
                const absDiff = new Decimal(actual.toString()).sub(expected).abs();
                expect(absDiff.div(expected).toNumber()).toBeLessThan(0.000001);
            }
        }
    });

    it("tick", async () => {
        expect(await test.getGetTickAtSqrtRatio(4295128739n)).toEqual(-887272n);
        expect(await test.getGetTickAtSqrtRatio(4295343490n)).toEqual(-887271n);
        expect(await test.getGetTickAtSqrtRatio(1461373636630004318706518188784493106690254656249n)).toEqual(887271n);
        expect(await test.getGetTickAtSqrtRatio(1461446703485210103287273052203988822378723970342n)).toEqual(887272n);
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
                const sqrtPrice = await test.getGetSqrtPriceAtTick(BigInt(tick));
                expect(await test.getGetTickAtSqrtRatio(sqrtPrice)).toEqual(BigInt(tick));
            }
        }
    });
});
