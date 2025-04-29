import { CompilerConfig } from '@ton/blueprint';

export const compile: CompilerConfig = {
    lang: 'tact',
    target: 'contracts/v3-tact/test/swap_math_test.tact',
    options: {
        debug: true,
    },
};
