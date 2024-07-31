import dotenv from 'dotenv'
import path from 'path'
import { ethers } from 'hardhat';

dotenv.config({path: path.resolve(__dirname, '../../.env')});

const contractName = 'LZV2OFT'
const mintAmount = ethers.utils.parseEther('100');

async function main() {
    const ContractFactory = await ethers.getContractFactory(contractName);
    const arbitrumSepoliaOFTContractAddr = process.env.ARBITRUM_SEPOLIA_OFT_ADDRESS || "0x";
    const user = process.env.EVM_USER_PUB_KEY || "0x";

    const contract = await ContractFactory.attach(arbitrumSepoliaOFTContractAddr);

    const mintTokenToUserTx = await contract.mint(user, mintAmount);
    console.log(`mintTokenToUserTx -> `, mintTokenToUserTx?.hash);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
