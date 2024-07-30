import { readdir } from "node:fs/promises";
import path from 'path';

type ExecOptions = {
    noThrow?: boolean;
};

export const getFolders = async (rootDir: string): Promise<string[]> => {
    return (await readdir(rootDir, { recursive: true, withFileTypes: true }))
        .filter(file => file.isDirectory())
        .map(file => `${path.join(file.parentPath, file.name)}`);
}

export const exec = async (cmdLike: string[] | string, env: {[key: string]: string}, options?: ExecOptions): Promise<number> => {
    const cmd = Array.isArray(cmdLike) ? cmdLike.join(" ") : cmdLike;
    return new Promise(async (resolve, reject) => {
        const proc = Bun.spawn({
            cmd: cmd.split(' '),
            env,
            onExit(_proc, exitCode, _signalCode, _error) {
                if (exitCode === 0) {
                    resolve(exitCode);
                } else if (options?.noThrow) {
                    resolve(exitCode || 1);
                } else {
                    reject(exitCode);
                }
            }
        });

        for await (const chunk of proc.stdout) {
            process.stdout.write(chunk);
        }
    });
}