const shell = require('shelljs');

/**
 *  User defined tasks
 */
task("check-libs-integrity", "Ensure that the libs are not modified", require("./core/check-libs-integrity"));

task(
    "forge-deploy",
    "Deploy using Foundry",
    require("./core/forgeDeploy")
)
    .addParam("script", "The script to use for deployment")
    .addFlag("broadcast", "broadcast the transaction")
    .addFlag("verify", "verify the contract")
    .addFlag("resume", "resume the script deployment")
    .addFlag("noConfirm", "do not ask for confirmation")
    .addOptionalVariadicPositionalParam("extra", "Extra arguments to pass to the script")

subtask(
    "check-console-log",
    "Check that contracts contains console.log and console2.log statements",
    require("./core/checkConsoleLog")
)
    .addParam("path", "The folder to check for console.log statements")

task("verify", "Verify a contract",
    require("./core/verify"))
    .addParam("deployment", "The name of the deployment (ex: MyContractName)")
    .addParam("artifact", "The artifact to verify (ex: src/periphery/MyContractName.sol:MyContractName)")
    .addFlag("showStandardJsonInput", "Show the standard json input to manually verify on etherscan")

task(
    "forge-deploy-multichain",
    "Deploy using Foundry on multiple chains",
    require("./core/forgeDeployMultichain"))
    .addParam("script", "The script to use for deployment")
    .addFlag("broadcast", "broadcast the transaction")
    .addFlag("verify", "verify the contract")
    .addFlag("resume", "resume the script deployment")
    .addFlag("noConfirm", "do not ask for confirmation")
    .addVariadicPositionalParam("networks", "The networks to deploy to")

task(
    "generate",
    "Generate a file from a template",
    require("./core/generate"))
    .addPositionalParam("template", "The template to use")


task("lzSetMinDstGas", "set min gas required on the destination gas", require("./lz/setMinDstGas"))
    .addParam("packetType", "message Packet type")
    .addParam("targetNetwork", "the chainId to transfer to")
    .addParam("contract", "contract name")
    .addParam("minGas", "min gas")

task(
    "lzSetTrustedRemote",
    "setTrustedRemote(chainId, sourceAddr) to enable inbound/outbound messages with your other contracts",
    require("./lz/setTrustedRemote")
).addParam("targetNetwork", "the target network to set as a trusted remote")
    .addOptionalParam("localContract", "Name of local contract if the names are different")
    .addOptionalParam("remoteContract", "Name of remote contract if the names are different")
    .addOptionalParam("contract", "If both contracts are the same name")
    .addFlag("noSubmit", "Do not submit the transaction, only get the contract address and hexdata")

task(
    "lzDeployOFTV2",
    "Deploy OFTV2 LayerZero stack",
    require("./lz/deployOFTV2"))
    .addFlag("broadcast", "broadcast the transaction")
    .addFlag("verify", "verify the contract")
    .addFlag("resume", "resume the script deployment")
    .addParam("token", "mim or spell")
    .addFlag("noConfirm", "do not ask for confirmation")

task(
    "lzDeployPrecrime",
    "Deploy MIM LayerZero stack",
    require("./lz/deployPrecrime"))
    .addFlag("broadcast", "broadcast the transaction")
    .addFlag("verify", "verify the contract")
    .addFlag("resume", "resume the script deployment")
    .addFlag("noConfirm", "do not ask for confirmation")
    .addParam("token", "mim or spell")

task(
    "lzChangeOwners",
    "Change owners of MIM LayerZero stack",
    require("./lz/changeOwners"))

task(
    "lzBridge",
    "Bridge MIM/SPELL from one network to another",
    require("./lz/bridge"))
    .addParam("from", "source network")
    .addParam("to", "destination network")
    .addOptionalParam("feeMultiplier", "fee multiplier")
    .addFlag("useWrapper", "use the wrapper contract to bridge")
    .addOptionalParam("gnosis", "use gnosis to bridge")
    .addParam("recipient", "recipient address")
    .addParam("token", "mim or spell")
    .addPositionalParam("amount", "amount in wei")


task("lzRetryFailedTx", "retry failed tx", require("./lz/retryFailedTx"))
    .addParam("tx", "transaction hash");

task("lzGnosisConfigure", "generate gnosis min gas required and or trusted remote on networks and or setPrecrime", require("./lz/gnosisConfigure"))
    .addParam("from", "comma separated networks (use all for all networks)")
    .addParam("to", "comma separated networks (use all for all networks)")
    .addFlag("setMinGas", "set min gas required on the destination gas")
    .addFlag("setRemotePath", "enable inbound/outbound messages with your other contracts")
    .addFlag("setPrecrime", "set precrime contract address from the deployment")
    .addFlag("closeRemotePath", "close the remote path")
    .addFlag("setOracle", "set the UA oracle address")
    .addFlag("setInputOutputLibraryVersion", "set the input output library version")

task("lzGnosisChangeOwners", "change operators", require("./lz/gnosisChangeOperators"));

task(
    "lzWithdrawFees",
    "Withdraw fees from fee collectors",
    require("./lz/withdrawFees"))
    .addOptionalVariadicPositionalParam("networks", "The networks to withdraw fees from")

task(
    "blocknumbers",
    "Retrieve the latest block numbers for each network",
    require("./core/blocknumbers"))

task(
    "lzCheckMimTotalSupply",
    "Retrieve mim total supply for each network versus locked supply in the mainnet procy",
    require("./lz/checkMimTotalSupply"))

task(
    "lzCheckPaths",
    "Check paths for each network",
    require("./lz/checkPaths"))


task("deploySpellStakingInfra", "Deploy Spell Staking stack",
    require("./deploySpellStakingInfra"))
    .addFlag("broadcast", "broadcast the transaction")
    .addFlag("verify", "verify the contract")
    .addFlag("noConfirm", "do not ask for confirmation");

task("deployCreate3Factories", "Deploy Create3Factory on all chains", require("./deployCreate3Factories"));

task("cauldronGnosisSetFeeTo", "generate gnosis transaction batch to change the feeTo", require("./cauldrons/gnosisSetFeeTo"));

task("lzGetDefaultConfig", "outputs the default Send and Receive Messaging Library versions and the default application config", require("./lz/uaGetDefaultConfig"))
    .addParam("networks", "comma separated list of networks")

task("lzGetConfig", "outputs the application's Send and Receive Messaging Library versions and the config for remote networks", require("./lz/uaGetConfig"))
    .addParam("token", "mim or spell")
    .addParam("from", "source network")
    .addParam("to", "destination network")

task(
    "cauldronsTopUp",
    "Top up Cauldrons",
    require("./cauldrons/topup"))
    .addParam("cauldrons", "comma separated cauldron name (see config/<network>.json for names)")
    .addParam("amounts", "comma separated cauldron mim amounts (same order as cauldrons)")

task(
    "cauldronInfo",
    "Get Cauldron info",
    require("./cauldrons/info"))
    .addParam("cauldron", "cauldron name (see config/<network>.json for names)")