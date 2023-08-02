const shell = require('shelljs');

// example:
// yarn task castDeploy --network base --args "0x000000000000000000000000fb3485c2e209a5cfbdc..." --code "0x60e0604052..." 
//                                                   ^ constructor args                                        ^ bytecode of the contract to deploy
module.exports = async function (taskArgs, hre) {
    cmd = `cast send --private-key ******* --rpc-url ${hre.network.config.url} --create ${taskArgs.code || "0x"} ${taskArgs.sig || ""} ${taskArgs.args || ""}`.replace(/\s+/g, ' ');
    console.log(cmd);
    result = await shell.exec(cmd.replace('*******', process.env.PRIVATE_KEY), { fatal: false });
}