import * as InstallLibsTask from './install-libs';
import * as CheckLibsIntegrityTask from './check-libs-integrity';

export const tasks = [
    InstallLibsTask,
    CheckLibsIntegrityTask
];