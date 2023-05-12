const shell = require('shelljs');

/**
 *  User defined tasks
 */
task(
    "forge-deploy",
    "Deploy using Foundry",
    require("./core/forge-deploy")
)
    .addParam("script", "The script to use for deployment")
    .addFlag("broadcast", "broadcast the transaction")
    .addFlag("verify", "verify the contract")
    .addFlag("resume", "resume the script deployment")
    .addFlag("noConfirm", "do not ask for confirmation", false)

subtask(
    "check-console-log",
    "Check that contracts contains console.log and console2.log statements",
    require("./core/check-console-log")
)
    .addParam("path", "The folder to check for console.log statements")

task(
    "forge-deploy-multichain",
    "Deploy using Foundry on multiple chains",
    require("./core/forge-deploy-multichain"))
    .addParam("script", "The script to use for deployment")
    .addFlag("broadcast", "broadcast the transaction")
    .addFlag("verify", "verify the contract")
    .addFlag("resume", "resume the script deployment")
    .addFlag("noConfirm", "do not ask for confirmation", false)
    .addVariadicPositionalParam("networks", "The networks to deploy to")

task(
    "generate",
    "Generate a file from a template",
    require("./core/generate"))
    .addPositionalParam("template", "The template to use")


task("setMinDstGas", "set min gas required on the destination gas", require("./lz/setMinDstGas"))
    .addParam("packetType", "message Packet type")
    .addParam("targetNetwork", "the chainId to transfer to")
    .addParam("contract", "contract name")
    .addParam("minGas", "min gas")

task(
    "setTrustedRemote",
    "setTrustedRemote(chainId, sourceAddr) to enable inbound/outbound messages with your other contracts",
    require("./lz/setTrustedRemote")
).addParam("targetNetwork", "the target network to set as a trusted remote")
    .addOptionalParam("localContract", "Name of local contract if the names are different")
    .addOptionalParam("remoteContract", "Name of remote contract if the names are different")
    .addOptionalParam("contract", "If both contracts are the same name")


task(
    "deploy-mim-layerzero",
    "Deploy MIM LayerZero stack",
    require("./deploy-mim-layerzero"))
    .addFlag("broadcast", "broadcast the transaction")
    .addFlag("verify", "verify the contract")
    .addFlag("resume", "resume the script deployment")