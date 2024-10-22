import fs from 'fs/promises';
import path from 'path';
import type { TaskArgs, TaskFunction, TaskMeta } from '../../types';
import type { Tooling } from '../../tooling';

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

    process.exit(0);
};

async function findConsoleImports(directory: string): Promise<string[]> {
    const files = await fs.readdir(directory, { withFileTypes: true });
    const results: string[] = [];

    for (const file of files) {
        const fullPath = path.join(directory, file.name);
        
        if (file.isDirectory()) {
            results.push(...await findConsoleImports(fullPath));
        } else if (file.isFile() && file.name.endsWith('.sol')) {
            const content = await fs.readFile(fullPath, 'utf-8');
            if (content.includes('console.sol') || content.includes('console2.sol')) {
                results.push(fullPath);
            }
        }
    }

    return results;
}
