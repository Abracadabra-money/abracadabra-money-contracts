const { types } = require("hardhat/config");

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
