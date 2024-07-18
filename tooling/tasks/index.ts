import * as InstallLibsTask from './core/install-libs';
import * as CheckLibsIntegrityTask from './core/check-libs-integrity';
import * as BlockNumberTask from './core/blocknumbers';
import * as CheckConsoleLogTask from './core/check-console-log';
import * as ForgeDeployTask from './core/forge-deploy';
import * as ForgeDeployMultichainTask from './core/forge-deploy-multichain';
import * as PostDeployTask from './core/post-deploy';
import * as VerifyTask from './core/verify';
import * as WithdrawFeesTask from './lz/withdraw-fees';
import * as CheckPathTasks from './lz/check-paths';
import * as BridgeTask from './lz/bridge';
import * as ChangeOwnersTask from './lz/change-owners';
import * as CheckMimTotalSupplyTask from './lz/check-mim-total-supply';
import * as DeployOFTV2Task from './lz/deploy-oftv2';
import * as DeployPrecrimeTask from './lz/deploy-precrime';
import * as ConfigureTask from './lz/configure';
import * as RetryFailedTask from './lz/retry-failed';
import * as SetMinDstGasTask from './lz/set-min-dst-gas';
import * as SetTrustedRemoteTask from './lz/set-trusted-remote';
import * as CauldronInfoTask from './cauldrons/info';
import * as CauldronGnosisSetFeeTooTask from './cauldrons/gnosis-set-feeto';
import * as GenerateMerkleAccountAmountTask from './gen/merkle-account-amount';
import * as GenerateTask from './gen/generate';

export const tasks = [
    InstallLibsTask,
    CheckLibsIntegrityTask,
    BlockNumberTask,
    CheckConsoleLogTask,
    ForgeDeployTask,
    ForgeDeployMultichainTask,
    PostDeployTask,
    VerifyTask,
    WithdrawFeesTask,
    CheckPathTasks,
    BridgeTask,
    ChangeOwnersTask,
    CheckMimTotalSupplyTask,
    DeployOFTV2Task,
    DeployPrecrimeTask,
    ConfigureTask,
    RetryFailedTask,
    SetMinDstGasTask,
    SetTrustedRemoteTask,
    CauldronInfoTask,
    CauldronGnosisSetFeeTooTask,
    GenerateMerkleAccountAmountTask,
    GenerateTask
];