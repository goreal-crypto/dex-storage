import { CompilerConfig } from '@ton/blueprint';

export const compile: CompilerConfig = {
    lang: 'tact',
    target: 'contracts/opt2/pool.tact',
    options: {
        debug: true,
    },
};
