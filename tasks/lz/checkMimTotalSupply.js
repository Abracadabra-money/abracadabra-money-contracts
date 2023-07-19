const { BigNumber } = require("ethers");

module.exports = async function (taskArgs, hre) {
    const { changeNetwork, getContractAt } = hre;

    taskArgs.networks = Object.keys(hre.config.networks);
    let altChainTotalSupply = BigNumber.from(0);
    let lockedAmount = BigNumber.from(0);

    for (const network of taskArgs.networks) {
        changeNetwork(network);

        const config = require(`../../config/${network}.json`);
        let mimAddress = config.addresses.find(a => a.key === "mim");
        if(!mimAddress) {
            console.log(`No MIM address found for ${network}`);
            process.exit(1);
        }

        mimAddress = mimAddress.value;
        const mim = await getContractAt("IERC20", mimAddress);

        if (network === "mainnet") {
            const tokenContract = await getContract("Mainnet_ProxyOFTV2", 1);
            lockedAmount = await mim.balanceOf(tokenContract.address);
            console.log(`Mainnet Locked Amount: ${parseFloat(ethers.utils.formatEther(lockedAmount)).toLocaleString()}`);

        }
        else {
            const totalSupply = await mim.totalSupply();
            altChainTotalSupply = altChainTotalSupply.add(totalSupply);
            console.log(`${network}: ${parseFloat(ethers.utils.formatEther(totalSupply)).toLocaleString()}`);
        }
    }
    console.log("=======");
    console.log(`Mainnet Locked Amount: ${parseFloat(ethers.utils.formatEther(lockedAmount)).toLocaleString()}`);
    console.log(`Alt Chain Total Supply: ${parseFloat(ethers.utils.formatEther(altChainTotalSupply)).toLocaleString()}`);

    if(altChainTotalSupply.gt(lockedAmount)) {
        console.log("Alt Chain Total Supply is greater than Mainnet Locked Amount!");
        process.exit(1);
    }
}