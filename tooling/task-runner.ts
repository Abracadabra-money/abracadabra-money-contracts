import { tooling } from './tooling';
import { parseArgs } from "util";
import { tasks as allTasks } from "./tasks";

import type { TaskArgs, TaskArgsOptions, TaskFunction, TaskMeta } from './types';

const tasks: { [key: string]: TaskMeta & { run: TaskFunction } } = {};
const taskArgs: TaskArgs = {};
const defaultOptions: TaskArgsOptions = {
    network: {
        type: 'string',
        required: false,
    }
}

let argv = Bun.argv.slice(2);

await tooling.init();

for (const task of allTasks) {
    tasks[task.meta.name] = {
        ...task.meta,
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
let values: any;
let positionals: any;

try {
    ({ values, positionals } = parseArgs({
        args: argv,
        options: {
            ...selectedTask.options,
            ...defaultOptions
        },
        strict: true,
        allowPositionals: true,
    }));
} catch (e: any) {
    console.error(e.message);
    process.exit(1);
}

const selectedNetwork = values.network as string || tooling.config.defaultNetwork;

if (!tooling.getNetworkConfigByName(selectedNetwork)) {
    console.error(`Network ${selectedNetwork} not found`);
    process.exit(1);
}

if (selectedTask.positionals) {
    taskArgs[selectedTask.positionals] = positionals;
}

// use selectedTask.options to parse the others
for (const key of Object.keys(selectedTask.options || {})) {
    if (!selectedTask.options) continue;

    const option = selectedTask.options[key];
    if (option.required) {
        if (option.type === 'boolean') {
            console.log(`boolean option '${key}' cannot be required`);
            process.exit(1);
        }

        if (!values[key]) {
            console.error(`Option ${key} is required`);
            process.exit(1);
        }
    }

    taskArgs[key] = values[key];

    if (option.type === 'boolean') {
        taskArgs[key] = !!(taskArgs[key] as boolean);
    }
}

tooling.changeNetwork(selectedNetwork);

console.log(`Running task ${task} using network ${selectedNetwork}...`);
await selectedTask.run(taskArgs, tooling);