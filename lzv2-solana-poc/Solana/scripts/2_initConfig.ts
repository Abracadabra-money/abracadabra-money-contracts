import accounts from "./getAccounts";
import { BN } from "@coral-xyz/anchor"
import {
    PublicKey,
    Transaction,
    SystemProgram,
    sendAndConfirmTransaction
} from "@solana/web3.js"
import {
    createSetAuthorityInstruction,
    AuthorityType,
    TOKEN_PROGRAM_ID
} from "@solana/spl-token"
import {
    OFT_SEED,
    OAPP_SEED,
    LZ_RECEIVE_TYPES_SEED,
    SEND_LIBRARY_CONFIG_SEED,
    RECEIVE_LIBRARY_CONFIG_SEED,
    PENDING_NONCE_SEED,
    NONCE_SEED,
    EventPDADeriver,
    EndpointProgram
} from '@layerzerolabs/lz-solana-sdk-v2';

const { connection, programId, program, adminKeypair, endpointProgramId, evmOftAddress, peer, tokenMint } = accounts;

const main = async () => {
    await initOftConfig();
    await initSendLibrary();
    await initReceiveLibrary();
    await initNonce();
}

const initOftConfig = async (decimals = 6) => {
    const [oftConfig] = PublicKey.findProgramAddressSync([Buffer.from(OFT_SEED), tokenMint.toBuffer()], programId);
    const [lzReceiveTypesAccounts] = PublicKey.findProgramAddressSync([Buffer.from(LZ_RECEIVE_TYPES_SEED), oftConfig.toBuffer()], programId);
    const [oappRegister] = PublicKey.findProgramAddressSync([Buffer.from(OAPP_SEED), oftConfig.toBuffer()], endpointProgramId);

    const transaction = new Transaction().add(
        createSetAuthorityInstruction(
            tokenMint,
            adminKeypair.publicKey,
            AuthorityType.MintTokens,
            oftConfig,
        ),
        await program.methods.initOft({
            admin: adminKeypair.publicKey,
            sharedDecimals: decimals,
            endpointProgram: endpointProgramId,
            mintAuthority: null
        }).accounts({
            payer: adminKeypair.publicKey,
            oftConfig,
            lzReceiveTypesAccounts,
            tokenMint: tokenMint,
            tokenProgram: TOKEN_PROGRAM_ID,
            systemProgram: SystemProgram.programId
        }).remainingAccounts([
            { // endpoint program
                pubkey: endpointProgramId,
                isSigner: false,
                isWritable: true
            },
            { // oapp register payer
                pubkey: adminKeypair.publicKey,
                isSigner: true,
                isWritable: true
            },
            { // oapp
                pubkey: oftConfig,
                isSigner: false,
                isWritable: true
            },
            { // oapp register pda
                pubkey: oappRegister,
                isSigner: false,
                isWritable: true
            },
            {
                pubkey: SystemProgram.programId,
                isSigner: false,
                isWritable: true
            },
            {
                pubkey: (new EventPDADeriver(endpointProgramId)).eventAuthority()[0],
                isSigner: false,
                isWritable: true
            },
            { // endpoint program
                pubkey: endpointProgramId,
                isSigner: false,
                isWritable: true
            },
        ])
            .instruction()
    );

    const txHash = await sendAndConfirmTransaction(connection, transaction, [adminKeypair]);

    console.log('txInitOftConfig -> ', txHash);

    console.log('You need to update .env variable like below:');
    console.log(`SOLANA_TESTNET_OFT_ADDRESS=`, oftConfig.toString());
}

const initSendLibrary = async () => {
    const [oftConfig] = PublicKey.findProgramAddressSync([Buffer.from(OFT_SEED), tokenMint.toBuffer()], programId);
    const [oappRegister] = PublicKey.findProgramAddressSync([Buffer.from(OAPP_SEED), oftConfig.toBuffer()], endpointProgramId);
    const [sendLibraryConfig] = PublicKey.findProgramAddressSync([Buffer.from(SEND_LIBRARY_CONFIG_SEED), oftConfig.toBuffer(), new BN(peer.dstEid).toArrayLike(Buffer, 'be', 4)], endpointProgramId);

    const initSendLibraryInstructionAccounts = {
        delegate: adminKeypair.publicKey,
        oappRegistry: oappRegister,
        sendLibraryConfig: sendLibraryConfig,
    }

    const initSendLibraryParams = {
        params: {
            oapp: oftConfig,
            sender: oftConfig,
            eid: peer.dstEid
        }
    }
    const sendLibraryInstruction = EndpointProgram.instructions.createInitSendLibraryInstruction(initSendLibraryInstructionAccounts, initSendLibraryParams, endpointProgramId)
    const transaction = new Transaction().add(sendLibraryInstruction);
    const txInitSendLibrary = await sendAndConfirmTransaction(connection, transaction, [adminKeypair])
    console.log("txInitSendLibrary -> ", txInitSendLibrary)
}

const initReceiveLibrary = async () => {
    const [oftConfig] = PublicKey.findProgramAddressSync([Buffer.from(OFT_SEED), tokenMint.toBuffer()], programId);
    const [oappRegister] = PublicKey.findProgramAddressSync([Buffer.from(OAPP_SEED), oftConfig.toBuffer()], endpointProgramId);
    const [receiveLibraryConfig] = PublicKey.findProgramAddressSync([Buffer.from(RECEIVE_LIBRARY_CONFIG_SEED), oftConfig.toBuffer(), new BN(peer.dstEid).toArrayLike(Buffer, 'be', 4)], endpointProgramId);

    const initReceiveLibraryInstructionAccounts = {
        delegate: adminKeypair.publicKey,
        oappRegistry: oappRegister, // comes from other
        receiveLibraryConfig: receiveLibraryConfig,
    }
    const initReceiveLibraryParams = {
        params: {
            receiver: oftConfig,
            eid: peer.dstEid
        }
    }
    const receiveLibraryInstruction = EndpointProgram.instructions.createInitReceiveLibraryInstruction(initReceiveLibraryInstructionAccounts, initReceiveLibraryParams, endpointProgramId)
    const transaction4 = new Transaction().add(receiveLibraryInstruction);
    const initReceiveLibTx = await sendAndConfirmTransaction(connection, transaction4, [adminKeypair])
    console.log("initReceiveLibTx -> ", initReceiveLibTx)
}

const initNonce = async () => {
    const [oftConfig] = PublicKey.findProgramAddressSync([Buffer.from(OFT_SEED), tokenMint.toBuffer()], programId);
    const [oappRegister] = PublicKey.findProgramAddressSync([Buffer.from(OAPP_SEED), oftConfig.toBuffer()], endpointProgramId);
    const [nonce] = PublicKey.findProgramAddressSync([Buffer.from(NONCE_SEED), oftConfig.toBuffer(), new BN(peer.dstEid).toArrayLike(Buffer, 'be', 4), evmOftAddress], endpointProgramId);
    const [pendingInboundNonce] = PublicKey.findProgramAddressSync([Buffer.from(PENDING_NONCE_SEED), oftConfig.toBuffer(), new BN(peer.dstEid).toArrayLike(Buffer, 'be', 4), evmOftAddress], endpointProgramId);

    const initNonceAccounts = {
        delegate: adminKeypair.publicKey,
        oappRegistry: oappRegister,
        nonce: nonce,
        pendingInboundNonce: pendingInboundNonce,
        SystemProgram: SystemProgram.programId
    }

    const initNonceParams = {
        params: {
            localOapp: oftConfig,
            remoteEid: peer.dstEid,
            remoteOapp: Array.from(evmOftAddress)
        }
    }

    const initNonceInstruction = EndpointProgram.instructions.createInitNonceInstruction(initNonceAccounts, initNonceParams, endpointProgramId)

    const _transaction = new Transaction().add(initNonceInstruction);
    const txInitNonce = await sendAndConfirmTransaction(connection, _transaction, [adminKeypair])
    console.log('txInitNonce -> ', txInitNonce);
}


main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
