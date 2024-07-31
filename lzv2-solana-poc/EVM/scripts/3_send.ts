import dotenv from 'dotenv'
import path from 'path'
import { ethers } from 'hardhat';
import { Options } from '@layerzerolabs/lz-v2-utilities'
import { EndpointId } from '@layerzerolabs/lz-definitions'
import bs58 from 'bs58';

dotenv.config({path: path.resolve(__dirname, '../../.env')});

const contractName = 'LZV2OFT'
const tokensToSend = ethers.utils.parseEther('10');

function base58ToUint8Array(base58: string): Uint8Array {
    return bs58.decode(base58);
}

async function main() {
    const ContractFactory = await ethers.getContractFactory(contractName);

    const arbitrumSepoliaOFTContractAddr = process.env.ARBITRUM_SEPOLIA_OFT_ADDRESS || "0x";
    const solanaUserPubkey = process.env.SOLANA_USER_PUB_KEY || "";

    let contract = await ContractFactory.attach(arbitrumSepoliaOFTContractAddr);
    const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL_ARBITRUMSEPOLIA || 'https://sepolia-rollup.arbitrum.io/rpc');
    const evmUserSigner = new ethers.Wallet(process.env.EVM_USER_PRIVATE_KEY || "0x", provider);

    const options = Options.newOptions()
        .addExecutorLzReceiveOption(200000, 0)
        .toHex().toString();

    const sendParam = [
        EndpointId.SOLANA_V2_TESTNET,
        ethers.utils.zeroPad(base58ToUint8Array(solanaUserPubkey), 32),
        tokensToSend,
        tokensToSend,
        options,
        '0x',
        '0x',
    ]
    const [nativeFee] = await contract.quoteSend(sendParam, false);
    console.log('nativeFee->', nativeFee);
    const sendArbToSolTx = await contract.connect(evmUserSigner).send(sendParam, [nativeFee, 0], evmUserSigner.address, { value: nativeFee });
    console.log("sendArbToSolTx-> ", sendArbToSolTx?.hash);
    
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
