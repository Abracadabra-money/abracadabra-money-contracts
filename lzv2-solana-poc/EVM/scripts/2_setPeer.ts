import dotenv from 'dotenv'
import path from 'path'
import { ethers } from 'hardhat'
import { EndpointId } from '@layerzerolabs/lz-definitions'
import bs58 from 'bs58';

dotenv.config({path: path.resolve(__dirname, '../../.env')});

const contractName = 'LZV2OFT'

function base58ToUint8Array(base58: string): Uint8Array {
    return bs58.decode(base58);
}

async function main() {

    const ContractFactory = await ethers.getContractFactory(contractName);

    const arbitrumSepoliaOFTContractAddr = process.env.ARBITRUM_SEPOLIA_OFT_ADDRESS || "0x";
    const solanaTestnetOftAddress = process.env.SOLANA_TESTNET_OFT_ADDRESS || "";

    const contract = await ContractFactory.attach(arbitrumSepoliaOFTContractAddr);
    const setPeerArbToSolTx = await contract.setPeer(EndpointId.SOLANA_V2_TESTNET, ethers.utils.zeroPad(base58ToUint8Array(solanaTestnetOftAddress), 32));
    console.log("setPeerArbToSolTx -> ", setPeerArbToSolTx?.hash);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
