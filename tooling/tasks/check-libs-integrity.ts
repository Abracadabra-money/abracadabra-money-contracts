import { $ } from 'bun';
import { join } from 'path';
import { readFileSync } from 'fs';
import { access, constants } from 'fs/promises';
import path from 'path';
import type { TaskArgs, TaskFunction, TaskMeta, Tooling } from '../types';

export const meta: TaskMeta = {
    name: 'integrity-check',
    description: 'Check integrity of solidity libraries from libs.json',
    options: {
        skip: {
            type: 'boolean'
        },
    },
};

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    const libs = JSON.parse(readFileSync(join(tooling.projectRoot, 'libs.json'), 'utf-8'));
    const libDir = path.join(tooling.projectRoot, 'lib');

    if (taskArgs.skip) {
        console.log("Skipping integrity check...");
        return;
    }

    await Promise.all(Object.keys(libs).map(async (target) => {
        const { commit } = libs[target];
        const dest = path.join(libDir, target);

        try {
            await access(dest, constants.R_OK);
        } catch {
            return;
        }

        // check commit hash
        let response = await $`(cd ${dest} && git rev-parse HEAD)`.quiet();
        if (response.stdout.toString().trim() == commit) {
            // check if there are changes
            response = await $`(cd ${dest} && git status --porcelain)`.quiet();
            if (response.stdout.length != 0) {
                console.log(`❌ ${target} integrity check failed, changes detected. Revert changes or run 'bun install' again.`);
                process.exit(1);
            }
        } else {
            console.log(`❌ ${target} version mismatch, run yarn again.`);
            process.exit(1);
        }
    }));
}