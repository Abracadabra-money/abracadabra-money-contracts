import {mkdir, rm} from "node:fs/promises";
import {join, dirname} from "path";
import chalk from "chalk";
import {$} from "bun";

export async function restoreFoundryProject(
    tempDir: string,
    standardJsonInput: any,
    compiler: string,
    artifact_full_path: string
): Promise<string> {
    await rm(tempDir, {recursive: true, force: true});
    await mkdir(tempDir, {recursive: true});
    console.log(`Using temporary directory: ${tempDir}`);

    let artifactFullPath;

    // Reconstruct source files
    for (const [filePath, source] of Object.entries(standardJsonInput.sources)) {
        const content = (source as {content: string}).content;
        const fullPath = join(tempDir, filePath);
        console.log(chalk.gray(` • Writing file: ${fullPath}`));
        await mkdir(dirname(fullPath), {recursive: true});
        await Bun.write(fullPath, content);

        // Match artifact_full_path with source file path
        const parts = filePath.split("/");
        const [artifactPath, contractName] = artifact_full_path.split(":");
        if (parts[parts.length - 1] === artifactPath) {
            artifactFullPath = `${filePath}:${contractName}`;
            console.log(chalk.gray(` • Matching artifact_full_path: ${artifactFullPath}`));
        }
    }

    if (!artifactFullPath) {
        throw new Error("Could not find matching source file for artifact_full_path");
    }

    // Create foundry.toml
    const foundryConfig = `
[profile.default]
src = '.'
out = 'out'
libs = ['lib']
remappings = ${JSON.stringify(standardJsonInput.settings.remappings)}
optimizer = ${standardJsonInput.settings.optimizer.enabled}
optimizer_runs = ${standardJsonInput.settings.optimizer.runs}
evm_version = '${standardJsonInput.settings.evmVersion}'
solc_version = '${compiler}'
    `.trim();

    await Bun.write(join(tempDir, "foundry.toml"), foundryConfig);

    // Compile the project
    console.log("Compiling the project...");
    await $`forge build --root ${tempDir}`.quiet();

    return artifactFullPath;
}
