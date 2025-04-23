import {Blockchain} from "@ton/sandbox"
import {Address, beginCell, Cell, toNano} from "@ton/core"

import { Router } from "../wrappers/Router";

const initializeDEXEnvironment = async () => {
    const blockchain = await Blockchain.create();

    const deployer = await blockchain.treasury("deployer");
    const notDeployer = await blockchain.treasury("notDeployer");

    const router = blockchain.openContract(
        await Router.fromInit(deployer.address, false)
    );

    const deployResult = await router.send(
        deployer.getSender(),
        {value: toNano("0.1")},
        null,
    );
}

const loadDEXEnvironment = initializeDEXEnvironment();

const lengthEqualsEither = (either: number, or: number) => (chainLength: number) =>
    chainLength === either || chainLength === or

export const runProvideLPBenchmark = async () => {
    
}