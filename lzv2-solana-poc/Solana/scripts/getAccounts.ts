import dotenv from 'dotenv'
import path from 'path'
import { AnchorProvider, Program } from "@coral-xyz/anchor";
import {
    Connection,
    clusterApiUrl,
    PublicKey,
    Keypair
} from '@solana/web3.js'
import { Lzv2oft as Lzv2oftIdl, IDL } from "../target/types/lzv2oft";
import { bs58 } from '@coral-xyz/anchor/dist/cjs/utils/bytes';

import {
    getEndpointProgramId,
    getExecutorProgramId,
    getPricefeedProgramId,
    getDVNProgramId,
    getULNProgramId,
} from '@layerzerolabs/lz-solana-sdk-v2';
import { EndpointId } from '@layerzerolabs/lz-definitions';
import { addressToBytes32 } from '@layerzerolabs/lz-v2-utilities';

dotenv.config({path: path.resolve(__dirname, '../../.env')});

const connection = new Connection(clusterApiUrl('testnet'), 'confirmed');
const provider = new AnchorProvider(connection, {} as any, AnchorProvider.defaultOptions());
const programId = new PublicKey(process.env.SOLANA_TESTNET_CONTRACT_ADDRESS);
const program = new Program<Lzv2oftIdl>(IDL as Lzv2oftIdl, programId, provider);
const adminKeypair = Keypair.fromSecretKey(bs58.decode(process.env.SOLANA_ADMIN_PRIVATE_KEY));
const userKeypair = Keypair.fromSecretKey(bs58.decode(process.env.SOLANA_USER_PRIVATE_KEY));
const endpointProgramId = getEndpointProgramId('solana-mainnet');
const sendLibraryProgram = new PublicKey("7a4WjyR8VZ7yZz5XJAKm39BUGn5iT9CKcv2pmG9tdXVH")
const executorProgramId = getExecutorProgramId("solana-mainnet")
const priceFeeProgramId = getPricefeedProgramId("solana-mainnet")
const dvnProgramId = getDVNProgramId("solana-mainnet");
const ulnProgramId = getULNProgramId("solana-mainnet");
const evmUser = addressToBytes32(process.env.EVM_USER_PUB_KEY);
const evmOftAddress = addressToBytes32(process.env.ARBITRUM_SEPOLIA_OFT_ADDRESS);
const peer = { dstEid: EndpointId.ARBSEP_V2_TESTNET, peerAddress: addressToBytes32(process.env.ARBITRUM_SEPOLIA_OFT_ADDRESS) };
const tokenMint = process.env.SOLANA_SPL_TOKEN_ADDRESS ? new PublicKey(process.env.SOLANA_SPL_TOKEN_ADDRESS) : PublicKey.default;

const accounts = {
    connection,
    provider,
    programId,
    program,
    adminKeypair,
    userKeypair,
    endpointProgramId,
    sendLibraryProgram,
    executorProgramId,
    priceFeeProgramId,
    dvnProgramId,
    ulnProgramId,
    evmUser,
    evmOftAddress,
    peer,
    tokenMint
}

export default accounts;