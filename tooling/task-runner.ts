import { tooling } from './tooling';
import { parseArgs } from "util";
import { tasks as allTasks } from "./tasks";
import camelToKebabCase from "camel-to-kebab";

import type { TaskArgs, TaskArgsOptions, TaskFunction, TaskMeta } from './types';
import chalk from 'chalk';

const tasks: { [key: string]: TaskMeta & { run: TaskFunction, curatedName: string } } = {};

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
    const parts = task.meta.name.split(':');
    const curatedName = parts.length > 1 ? parts.slice(1).join(':') : parts[0];
    tasks[curatedName] = {
        ...task.meta,
        curatedName,
        run: task.task
    };
}

const displayTask = (task: TaskMeta & { curatedName: string }) => {
    console.log(`  ${chalk.green(task.curatedName)}: ${task.description}`);

    if (task.positionals) {
        console.log(`    ${chalk.cyan('Positionals:')} ${task.positionals}`);
    }

    if (task.options && Object.keys(task.options).length > 0) {
        console.log(`    ${chalk.cyan('Options:')}`);
        for (const [key, option] of Object.entries(task.options)) {
            const optionDetails = `${key} (${option.type}${option.required ? ', required' : ''}${option.default !== undefined ? `, default: ${option.default}` : ''})`;
            console.log(`      ${chalk.blue(optionDetails)}: ${option.description || 'No description'}`);
        }
    }
};

const showHelp = () => {
    console.log(chalk.yellow(`Usage: bun task <task> [options] [positionals]`));
    console.log(chalk.yellow('Tasks:'));

    const sortedTasks = Object.values(tasks).sort((a, b) => a.name.localeCompare(b.name));
    const tasksWithoutPrefix = sortedTasks.filter(task => !task.name.includes(':'));
    const tasksWithPrefix = sortedTasks.filter(task => task.name.includes(':'));

    console.log(`\n${chalk.bold.underline.blue('GENERAL')}`);

    tasksWithoutPrefix.forEach(displayTask);

    let currentPrefix = '';
    tasksWithPrefix.forEach(task => {
        const [prefix] = task.name.split(':');
        if (prefix !== currentPrefix) {
            currentPrefix = prefix;
            console.log(`\n${chalk.bold.underline.blue(prefix.toUpperCase())}`);
        }
        displayTask(task);
    });
    console.log('');
}

const task = argv[0];

if (!task || task === 'help') {
    showHelp();
    process.exit(0);
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

const processedSelectedTaskOptions: TaskArgsOptions = {};

if (selectedTask.options) {
    for (const key of Object.keys(selectedTask.options)) {
        processedSelectedTaskOptions[camelToKebabCase(key)] = selectedTask.options[key];
    }
}

try {
    ({ values, positionals } = parseArgs({
        args: argv,
        options: {
            ...processedSelectedTaskOptions,
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

if (selectedTask.positionals && positionals.length > 0) {
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

    if (option.validate) {
        try {
            option.validate(values[key]);
        } catch (e: any) {
            console.error(e.message);
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