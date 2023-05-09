task(
    "forge-deploy",
    "Deploy using Foundry",
    require("./core/forge-deploy")
)
    .addParam("script", "The script to use for deployment")
    .addFlag("broadcast", "broadcast the transaction")
    .addFlag("verify", "verify the contract")
    .addFlag("resume", "resume the script deployment")

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
    .addVariadicPositionalParam("networks", "The networks to deploy to")

task(
    "generate",
    "Generate a file from a template",
    require("./core/generate"))
    .addPositionalParam("template", "The template to use")

task(
    "deploy-mim-layerzero",
    "Deploy MIM LayerZero stack",
    require("./deploy-mim-layerzero"))
    .addFlag("broadcast", "broadcast the transaction")
    .addFlag("verify", "verify the contract")
    .addFlag("resume", "resume the script deployment")