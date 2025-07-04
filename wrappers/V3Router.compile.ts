import { CompilerConfig } from '@ton/blueprint';

export const compile: CompilerConfig = {
    lang: 'tact',
    target: 'contracts/v3-tact/router.tact',
    options: {
        debug: true,
    },
};
