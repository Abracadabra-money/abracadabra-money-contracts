import { $ } from 'bun';
import { join } from 'path';
import { readFileSync } from 'fs';
import { rm } from 'fs/promises';
import { readdir } from 'fs/promises';
import path from 'path';
import type { TaskArgs, TaskFunction, TaskMeta, Tooling } from '../types';

export const meta: TaskMeta = {
    name: 'install-libs',
    description: 'Install solidity libraries from libs.json',
    options: {
        force: {
            type: 'boolean'
        },
        foo: {
            type: 'string',
        }
    },
    positionals: 'others'
};

export const task: TaskFunction = async (taskArgs: TaskArgs, tooling: Tooling) => {
    const libs = JSON.parse(readFileSync(join(tooling.projectRoot, 'libs.json'), 'utf-8'));
    const destination = path.join(tooling.projectRoot, 'lib');

    // delete all folder not in libs
    try {
        const folders = await readdir(destination);
        await Promise.all(folders.map(async (folder) => {
            if (!libs[folder]) {
                await rm(path.join(destination, folder), { recursive: true, force: true });
            }
        }));
    } catch (err) {
        console.error(err);
    }

    const keys = Object.keys(libs);
    for (let i = 0; i < keys.length; i++) {
        const target = keys[i];
        const { url, commit } = libs[target];
        const dest = path.join(destination, target);
        let installed = false;

        // check commit hash
        try {
            let response = await $`(cd ${dest} && git rev-parse HEAD)`.quiet();
            if (response.stdout.toString().trim() === commit) {
                // check if there are changes
                response = await $`(cd ${dest} && git status --porcelain)`.quiet();
                installed = response.stdout.length === 0;
            }
        } catch (e) { }

        if (installed) {
            console.log(`✨ ${target} already installed`);
            continue;
        }

        await rm(dest, { recursive: true, force: true });

        console.log(`✨ Installing ${url}#${commit} to ${target}`);
        await $`git clone ${url} ${dest}`.quiet();

        if ((await $`(cd ${dest} && git cat-file -t ${commit})`.quiet().text()).trim() !== 'commit') {
            console.log(`❌ ${target}, commit ${commit} not found.`);
            process.exit(1);
        }

        await $`(cd ${dest} && git checkout ${commit})`.quiet();
        await $`(cd ${dest} && git submodule update --init --recursive)`.quiet();
    }
}