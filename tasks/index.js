task(
    "forge-deploy",
    "Deploy using Foundry",
    require("./forge-deploy")
)
    .addParam("script", "The script to use for deployment")
    .addFlag("broadcast", "broadcast the transaction")
    .addFlag("verify", "verify the contract")
    .addFlag("resume", "resume the script deployment")

subtask(
    "check-console-log",
    "Check that contracts contains console.log and console2.log statements",
    require("./check-console-log")
)
    .addParam("path", "The folder to check for console.log statements")

task(
    "forge-deploy-multichain",
    "Deploy using Foundry on multiple chains",
    require("./forge-deploy-multichain"))
    .addParam("script", "The script to use for deployment")
    .addVariadicPositionalParam("networks", "The networks to deploy to")


task(
    "generate",
    "Generate a file from a template",
    require("./generate"))
    .addPositionalParam("template", "The template to use")
