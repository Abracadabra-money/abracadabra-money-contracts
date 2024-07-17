import { basename } from 'path';
import { readFileSync, writeFileSync } from 'fs';
import type { TaskArgs, TaskFunction, TaskMeta, Tooling } from '../types';
import { createAccountAmountMerkleTree } from './utils/merkle';

export const meta: TaskMeta = {
    name: 'create-merkle-tree',
    description: 'Create a Merkle tree from a CSV file',
    options: {
        cvs: {
            type: 'string',
            required: true,
        },
    },
};

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    const items: [string, string][] = [];

    console.log(`Processing ${taskArgs.cvs}...`);

    readFileSync(taskArgs.cvs as string, 'utf8').split(/\r?\n/).forEach((line) => {
        if (line) {
            const [address, amount] = line.split(';');
            items.push([address.trim(), amount.trim()]);
        }
    });

    console.log(`Creating merkle tree...`);
    const tree = createAccountAmountMerkleTree(items);
    const json = JSON.stringify(tree, null, 4);
    console.log(json);

    const out = `${basename(taskArgs.cvs as string, '.csv')}.proofs.json`;
    writeFileSync(out, json, 'utf8');
    console.log(`Merkle tree saved to ${out}`);
};
