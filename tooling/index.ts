import { tooling } from './tooling';
import { parseArgs } from "util";

//await tooling.init('bera');

const defaultOptions = {
    network: 'string'
}

const { values, positionals } = parseArgs({
    args: Bun.argv,
    options: {
        flag1: {
            type: 'boolean',
        },
        flag2: {
            type: 'string',
        },
    },
    strict: true,
    allowPositionals: true,
});

console.log(values);
console.log(positionals);