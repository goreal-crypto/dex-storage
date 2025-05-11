import { Blockchain, internal, printTransactionFees, SandboxContract, TreasuryContract } from '@ton/sandbox';
import { beginCell, Builder, Dictionary, toNano } from '@ton/core';
import '@ton/test-utils';
import { encodeSqrtRatioX96, getMaxTick, getMinTick } from '../utils/math';
import { TickMathTest } from '../build/TickMathTest/tact_TickMathTest';
import { getUsedGasInternal } from '../utils/gas';


describe("V3Router", () => {
    let blockchain: Blockchain;
    let user: SandboxContract<TreasuryContract>;
    let admin: SandboxContract<TreasuryContract>;
    let router: SandboxContract<TreasuryContract>;
    let token0: SandboxContract<TreasuryContract>;
    let token1: SandboxContract<TreasuryContract>;
    let token2: SandboxContract<TreasuryContract>;


    beforeEach(async () => {
        blockchain = await Blockchain.create();
        user = await blockchain.treasury("user");
        admin = await blockchain.treasury("admin");
        token0 = await blockchain.treasury("token0Address");
        token1 = await blockchain.treasury("token1Address");
        token2 = await blockchain.treasury("token2Address");
    });
});