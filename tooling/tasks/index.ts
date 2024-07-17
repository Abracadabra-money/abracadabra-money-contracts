import * as InstallLibsTask from './core/install-libs';
import * as CheckLibsIntegrityTask from './core/check-libs-integrity';
import * as BlockNumberTask from './core/blocknumbers';
import * as WithdrawFeesTask from './lz/withdraw-fees';
import * as CauldronInfoTask from './cauldrons/info';
import * as CauldronGnosisSetFeeTooTask from './cauldrons/gnosis-set-feeto';
import * as GenerateMerkleAccountAmountTask from './gen/merkle-account-amount';
import * as CheckPathTasks from './lz/check-paths';

export const tasks = [
    InstallLibsTask,
    CheckLibsIntegrityTask,
    BlockNumberTask,
    WithdrawFeesTask,
    CauldronInfoTask,    
    CauldronGnosisSetFeeTooTask,
    GenerateMerkleAccountAmountTask,
    CheckPathTasks
];