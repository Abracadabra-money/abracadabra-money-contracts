import assert from 'assert'

import { type DeployFunction } from 'hardhat-deploy/types'

const lzV2OftContractName = 'LZV2OFT'

const deploy: DeployFunction = async (hre) => {
    const { getNamedAccounts, deployments } = hre

    const { deploy } = deployments
    const { deployer } = await getNamedAccounts()

    assert(deployer, 'Missing named deployer account')

    console.log(`Network: ${hre.network.name}`)
    console.log(`Deployer: ${deployer}`)
    
    const endpointV2Deployment = await hre.deployments.get('EndpointV2')

    const lzV2OftContractAddress = (await deploy(lzV2OftContractName, {
        from: deployer,
        args: [
            `LZV2OFT`, // name
            `LZOFT`, // symbol
            endpointV2Deployment.address, // LayerZero's EndpointV2 address
            deployer, // owner
        ],
        log: true,
        skipIfAlreadyDeployed: false,
    })).address;

    console.log(`Deployed contract: ${lzV2OftContractName}, network: ${hre.network.name}, address: ${lzV2OftContractAddress}`);

    console.info('You need to update .env variables below:');
    console.info(`ARBITRUM_SEPOLIA_OFT_ADDRESS=${lzV2OftContractAddress}`)

}

deploy.tags = [lzV2OftContractName]

export default deploy
