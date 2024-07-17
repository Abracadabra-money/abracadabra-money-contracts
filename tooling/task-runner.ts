import { tooling } from './tooling';
import { parseArgs } from "util";
import { tasks as allTasks } from "./tasks";

import type { TaskArgs, TaskArgsOptions, TaskFunction, TaskMeta } from './types';

const tasks: { [key: string]: TaskMeta & { run: TaskFunction } } = {};

let argv = Bun.argv.slice(2);

for (const task of allTasks) {
    tasks[task.meta.name] = {
        name: task.meta.name,
        description: task.meta.description,
        options: task.meta.options,
        run: task.task
    };
}

const showHelp = () => {
    console.log('Usage: tooling <task> [options]');
    console.log('Tasks:');
    for (const task of Object.values(tasks)) {
        console.log(`  ${task.name}: ${task.description}`);
    }
    process.exit(1);
}

const task = argv[0];

if (!task) {
    console.error('No task specified');
    process.exit(1);
}

if (!tasks[task]) {
    console.error(`Task ${task} not found`);
    showHelp();
    process.exit(1);
}

argv = argv.slice(1);

const selectedTask = tasks[task];
const defaultOptions: TaskArgsOptions = {
    network: {
        type: 'string',
        required: false,
    }
}

let { values, positionals } = parseArgs({
    args: Bun.argv,
    options: {
        ...selectedTask.options,
        ...defaultOptions
    },
    strict: false,
    allowPositionals: true,
});

await tooling.init();
const selectedNetwork = values.network as string || tooling.config.defaultNetwork;

if (!tooling.getNetworkConfigByName(selectedNetwork)) {
    console.error(`Network ${selectedNetwork} not found`);
    process.exit(1);
}

console.log(`Running task ${task} using network ${selectedNetwork}...`);

const taskArgs: TaskArgs = {};
positionals = positionals.slice(3);

if (selectedTask.positionals) {
    taskArgs[selectedTask.positionals] = positionals;
}
