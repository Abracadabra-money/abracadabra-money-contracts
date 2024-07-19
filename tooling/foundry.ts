import { $ } from "bun";

export const getForgeConfig = async () => JSON.parse(await $`forge config --json`.quiet().text());
