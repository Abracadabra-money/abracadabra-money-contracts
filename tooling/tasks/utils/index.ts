import { readdir } from "node:fs/promises";
import path from 'path';

export const getFolders = async (rootDir: string): Promise<string[]> => {
    return (await readdir(rootDir, { recursive: true, withFileTypes: true }))
        .filter(file => file.isDirectory())
        .map(file => `${path.join(file.parentPath, file.name)}`);
}