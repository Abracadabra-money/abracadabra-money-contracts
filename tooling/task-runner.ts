import {tooling} from "./tooling";
import {parseArgs} from "util";
import {tasks as allTasks} from "./tasks";
import camelToKebabCase from "camel-to-kebab";

import type {NetworkName, TaskArgs, TaskArgsOptions, TaskFunction, TaskMeta} from "./types";
import chalk from "chalk";
import {showError} from "./tasks/utils";

const TASK_GROUP_SEPARATOR = "/";
const _tasks: {[key: string]: TaskMeta & {run: TaskFunction; curatedName: string}} = {};

const taskArgs: TaskArgs = {};
const defaultOptions: TaskArgsOptions = {
    network: {
        type: "string",
        required: false,
    },
    help: {
        type: "boolean",
    },
};

const _initTasks = () => {
    for (const task of allTasks) {
        const parts = task.meta.name.split(TASK_GROUP_SEPARATOR);
        const curatedName = parts.length > 1 ? parts.slice(1).join(TASK_GROUP_SEPARATOR) : parts[0];

        if (_tasks[curatedName]) {
            throw new Error(`${_tasks[curatedName].name} in ${task.meta.name} name conflict, name ${curatedName} must be unique`);
        }

        _tasks[curatedName] = {
            ...task.meta,
            curatedName,
            run: task.task,
        };

        // also add an alias for group:taskname, for example lz/configure can be called with lz:configure
        _tasks[`${parts[0]}:${curatedName}`] = _tasks[curatedName];
    }
};

const _runTask = async (task: TaskMeta & {run: TaskFunction}, args: TaskArgs) => {
    await task.run(args, tooling);
};

const _displayTask = (task: TaskMeta & {curatedName: string}) => {
    console.log(`  ${chalk.green(task.curatedName)} ${task.description}`);

    if (task.options && Object.keys(task.options).length > 0) {
        for (const [key, option] of Object.entries(task.options)) {
            const kebakKey = camelToKebabCase(key);

            let optionDetails;

            if (option.choices) {
                optionDetails = `--${kebakKey} (choice${option.required ? ", required" : ""}${
                    option.default !== undefined ? `, default: ${option.default}` : ""
                }) [${option.choices.join(", ")}]`;
            } else {
                optionDetails = `--${kebakKey} (${option.type}${option.required ? ", required" : ""}${
                    option.default !== undefined ? `, default: ${option.default}` : ""
                })`;
            }

            console.log(`      ${chalk.blue(optionDetails)}: ${option.description || ""}`);
        }
    }

    if (task.positionals) {
        console.log(`    ${chalk.cyan("Positionals:")} ${task.positionals.name}`);
        console.log(`      ${chalk.blue(task.positionals?.description || "")}`);

        if (task.positionals.choices) {
            console.log(`      ${chalk.blue(`[${task.positionals.choices.join(", ")}]`)}`);
        }
    }
};

const _showHelp = () => {
    console.log(chalk.yellow(`Usage: bun task <task> [options] [positionals]`));
    console.log(chalk.yellow("Tasks:"));

    const sortedTasks = Object.values(_tasks).sort((a, b) => a.name.localeCompare(b.name));
    const tasksWithoutPrefix = sortedTasks.filter((task) => !task.name.includes(TASK_GROUP_SEPARATOR));
    const tasksWithPrefix = sortedTasks.filter((task) => task.name.includes(TASK_GROUP_SEPARATOR));

    console.log(`\n${chalk.bold.underline.blue("GENERAL")}`);

    tasksWithoutPrefix.forEach(_displayTask);

    let currentPrefix = "";
    tasksWithPrefix.forEach((task) => {
        const [prefix] = task.name.split(TASK_GROUP_SEPARATOR);
        if (prefix !== currentPrefix) {
            currentPrefix = prefix;
            console.log(`\n${chalk.bold.underline.blue(prefix.toUpperCase())}`);
        }
        _displayTask(task); // Changed from _displayTask to displayTask
    });
    console.log("");
};

const _main = async () => {
    await tooling.init();
    _initTasks();

    let argv = Bun.argv.slice(2);
    const task = argv[0];

    if (!task || task === "help") {
        _showHelp();
        process.exit(0);
    }

    if (!_tasks[task]) {
        console.error(`Task ${task} not found`);
        _showHelp();
        process.exit(1);
    }

    argv = argv.slice(1);

    const selectedTask = _tasks[task];
    let values: any;
    let positionals: any;

    const camelToKebakTaskOptions: TaskArgsOptions = {};
    const kebabToCamelCaseMap: {[key: string]: string} = {};

    if (selectedTask.options) {
        for (const key of Object.keys(selectedTask.options)) {
            const kebakKey = camelToKebabCase(key);
            camelToKebakTaskOptions[kebakKey] = selectedTask.options[key];
            kebabToCamelCaseMap[key] = kebakKey;
        }
    }

    try {
        ({values, positionals} = parseArgs({
            args: argv,
            options: {
                ...camelToKebakTaskOptions,
                ...defaultOptions,
            },
            strict: true,
            allowPositionals: !!selectedTask.positionals,
        }));
    } catch (e: any) {
        console.error(e.message);
        process.exit(1);
    }

    if (values.help) {
        _displayTask(selectedTask);
        process.exit(0);
    }

    const selectedNetwork = (values.network as NetworkName) || tooling.config.defaultNetwork;
    if (!tooling.getNetworkConfigByName(selectedNetwork)) {
        console.error(`Network ${selectedNetwork} not found`);
        process.exit(1);
    }

    if (selectedTask.positionals) {
        if (positionals.length > 0) {
            if (selectedTask.positionals.choices) {
                if (selectedTask.positionals.maxPostionalCount && positionals.length > selectedTask.positionals.maxPostionalCount) {
                    console.error(
                        `Positional ${selectedTask.positionals.name} must have at most ${
                            selectedTask.positionals.maxPostionalCount
                        } value [${selectedTask.positionals.choices.join(", ")}}`
                    );
                    process.exit(1);
                }
                // parse the positionnal up to selectedTask.positionals.maxPostionalCount
                for (let i = 0; i < (selectedTask.positionals.maxPostionalCount || positionals.length); i++) {
                    if (!selectedTask.positionals.choices.includes(positionals[i])) {
                        console.error(
                            `${positionals[i]} is not a valid ${
                                selectedTask.positionals.name
                            } value, must be one of ${selectedTask.positionals.choices.join(", ")}`
                        );
                        process.exit(1);
                    }
                }
            }
            taskArgs[selectedTask.positionals.name] = positionals;
        } else if (selectedTask.positionals?.required) {
            console.error(`Positional ${selectedTask.positionals.name} is required`);
            process.exit(1);
        }
    }

    // use selectedTask.options to parse the others
    for (const camelCaseKey of Object.keys(selectedTask.options || {})) {
        if (!selectedTask.options) continue;

        const option = selectedTask.options[camelCaseKey];
        const kebakKey = camelToKebabCase(camelCaseKey);

        if (option.required) {
            if (option.type === "boolean") {
                console.log(`boolean option '${camelCaseKey}' cannot be required`);
                process.exit(1);
            }

            if (!values[kebakKey]) {
                console.error(`Option --${kebakKey} is required`);
                process.exit(1);
            }
        }

        if (option.choices && (option.required || values[kebakKey] !== undefined) && !option.choices.includes(values[kebakKey])) {
            console.error(`Option ${camelCaseKey} must be one of ${option.choices.join(", ")}`);
            process.exit(1);
        }

        taskArgs[camelCaseKey] = values[kebakKey];

        if (option.type === "boolean") {
            taskArgs[camelCaseKey] = !!(taskArgs[camelCaseKey] as boolean);
        }

        if (option.transform) {
            taskArgs[camelCaseKey] = option.transform(taskArgs[camelCaseKey]);
        }
    }

    await tooling.changeNetwork(selectedNetwork);

    try {
        await runTask(task, taskArgs);
    } catch (e) {
        showError(`An error occurred while running the task ${task}:`, e);
    }
};

export const runTask = async (taskName: string, args: TaskArgs = {}) => {
    if (!_tasks[taskName]) {
        throw new Error(`Task ${taskName} not found`);
    }

    await _runTask(_tasks[taskName], args);
};

await _main();
