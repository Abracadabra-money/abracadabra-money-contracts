import * as InstallLibsTask from './install-libs';
import * as CheckLibsIntegrityTask from './check-libs-integrity';
import * as BlockNumberTask from './blocknumbers';

export const tasks = [
    InstallLibsTask,
    CheckLibsIntegrityTask,
    BlockNumberTask
];