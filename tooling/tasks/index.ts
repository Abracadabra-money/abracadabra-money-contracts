import * as BlockNumberTask from "./core/blocknumbers";
import * as CheckConsoleLogTask from "./core/check-console-log";
import * as ForgeDeployTask from "./core/forge-deploy";
import * as ForgeDeployMultichainTask from "./core/forge-deploy-multichain";
import * as PostDeployTask from "./core/post-deploy";
import * as VerifyTask from "./core/verify";
import * as SyncDeploymentsTask from "./core/sync-deployments";
import * as AddressTask from "./core/address";
import * as WithdrawFeesTask from "./lz/withdraw-fees";
import * as CheckPathTasks from "./lz/check-paths";
import * as BridgeTask from "./lz/bridge";
import * as ChangeOwnersTask from "./lz/change-owners";
import * as CheckMimTotalSupplyTask from "./lz/check-mim-total-supply";
import * as DeployOFTV2Task from "./lz/deploy-oftv2";
import * as ConfigureTask from "./lz/configure";
import * as RetryFailedTask from "./lz/retry-failed";
import * as SetMinDstGasTask from "./lz/set-min-dst-gas";
import * as SetTrustedRemoteTask from "./lz/set-trusted-remote";
import * as UAGetConfigTask from "./lz/ua-get-config";
import * as UAGetDefaultConfigTask from "./lz/ua-get-default-config";
import * as CauldronInfoTask from "./cauldrons/info";
import * as CauldronGnosisSetFeeTooTask from "./cauldrons/gnosis-set-feeto";
import * as GenerateMerkleAccountAmountTask from "./gen/merkle-account-amount";
import * as GenerateTask from "./gen/generate";

export const tasks = [
    BlockNumberTask,
    CheckConsoleLogTask,
    ForgeDeployTask,
    ForgeDeployMultichainTask,
    PostDeployTask,
    VerifyTask,
    SyncDeploymentsTask,
    AddressTask,
    WithdrawFeesTask,
    CheckPathTasks,
    BridgeTask,
    ChangeOwnersTask,
    CheckMimTotalSupplyTask,
    DeployOFTV2Task,
    ConfigureTask,
    RetryFailedTask,
    SetMinDstGasTask,
    SetTrustedRemoteTask,
    UAGetConfigTask,
    UAGetDefaultConfigTask,
    CauldronInfoTask,
    CauldronGnosisSetFeeTooTask,
    GenerateMerkleAccountAmountTask,
    GenerateTask,
];
