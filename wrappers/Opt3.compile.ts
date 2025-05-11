import { CompilerConfig } from '@ton/blueprint';

export const compile: CompilerConfig = {
    lang: 'tact',
    target: 'contracts/opt3/pool.tact',
    options: {
        debug: true,
    },
};
