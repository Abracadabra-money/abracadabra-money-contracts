import { $ } from 'bun';
import path from 'path';
import type { TaskArgs, TaskFunction, TaskMeta } from '../../types';
import type { Tooling } from '../../tooling';

export const meta: TaskMeta = {
    name: 'core/check-console-log',
    description: 'Check whether console.sol or console2.sol is used in the codebase'
};

export const task: TaskFunction = async (_: TaskArgs, tooling: Tooling) => {
    const src = path.join(tooling.config.projectRoot, tooling.config.foundry.src);
    const result = await $`grep -rlw --max-count=1 --include=\*.sol '${src}' -e 'console\.sol'; grep -rlw --max-count=1 --include=\*.sol '${src}' -e 'console2\.sol'`.quiet().nothrow();

    if(result.exitCode === 0) {
        console.error(`Found console log import in ${result.stdout.toString()}`);
        process.exit(1);
    }
};