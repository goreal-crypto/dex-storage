import { CompilerConfig } from '@ton/blueprint';

export const compile: CompilerConfig = {
    lang: 'tact',
    target: 'contracts/opt1/pool.tact',
    options: {
        debug: true,
    },
};
