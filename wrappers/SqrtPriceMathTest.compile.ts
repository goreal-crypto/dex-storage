import { CompilerConfig } from '@ton/blueprint';

export const compile: CompilerConfig = {
    lang: 'tact',
    target: 'contracts/v3-tact/test/sqrt_price_math_test.tact',
    options: {
        debug: true,
    },
};
