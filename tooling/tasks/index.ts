import * as InstallLibsTask from './install-libs';
import * as CheckLibsIntegrityTask from './check-libs-integrity';
import * as BlockNumberTask from './blocknumbers';
import * as WithdrawFeesTask from './lz/withdraw-fees';

export const tasks = [
    InstallLibsTask,
    CheckLibsIntegrityTask,
    BlockNumberTask,
    WithdrawFeesTask
];