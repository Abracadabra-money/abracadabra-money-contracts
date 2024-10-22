import { file } from 'bun';
import path from 'path';
import type { TaskArgs, TaskFunction, TaskMeta } from '../../types';
import type { Tooling } from '../../tooling';
import { readdir, readFile } from 'fs/promises';

export const meta: TaskMeta = {
    name: 'core/check-console-log',
    description: 'Check whether console.sol or console2.sol is used in the codebase'
};

export const task: TaskFunction = async (_: TaskArgs, tooling: Tooling) => {
    const src = path.join(tooling.config.projectRoot, tooling.config.foundry.src);
    const consoleImports = await findConsoleImports(src);

    if (consoleImports.length > 0) {
        console.error(`Found console log import in:\n${consoleImports.join('\n')}`);
        process.exit(1);
    }
};

async function findConsoleImports(directory: string): Promise<string[]> {
    const results: string[] = [];
    const entries = await readdir(directory, { withFileTypes: true });

    for (const entry of entries) {
        const fullPath = path.join(directory, entry.name);
        if (entry.isDirectory()) {
            results.push(...await findConsoleImports(fullPath));
        } else if (entry.isFile() && entry.name.endsWith('.sol')) {
            const content = await readFile(fullPath, 'utf-8');
            if (content.includes('console.sol') || content.includes('console2.sol')) {
                results.push(fullPath);
            }
        }
    }

    return results;
}
