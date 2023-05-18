const shell = require('shelljs');

/**
 *  User defined tasks
 */
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


task(
    "lzDeployMIM",
    "Deploy MIM LayerZero stack",
    require("./lz/deployMIM"))
    .addFlag("broadcast", "broadcast the transaction")
    .addFlag("verify", "verify the contract")
    .addFlag("resume", "resume the script deployment")
    .addFlag("noConfirm", "do not ask for confirmation")

task(
    "lzBridgeMIM",
    "Bridge MIM from one network to another",
    require("./lz/bridgeMIM"))
    .addParam("from", "source network")
    .addParam("to", "destination network")
    .addPositionalParam("amount", "MIM amount in wei")
