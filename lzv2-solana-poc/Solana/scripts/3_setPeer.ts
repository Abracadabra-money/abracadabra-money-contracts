import accounts from "./getAccounts";
import { BN } from "@coral-xyz/anchor"
import {
    PublicKey,
    Transaction,
    SystemProgram,
    sendAndConfirmTransaction
} from "@solana/web3.js"
import {
    OFT_SEED,
    PEER_SEED,
    ENFORCED_OPTIONS_SEED,
} from '@layerzerolabs/lz-solana-sdk-v2';
import { Options } from '@layerzerolabs/lz-v2-utilities';

const { connection, programId, program, adminKeypair, peer, tokenMint } = accounts;

const main = async () => {
    await setPeer();
    await setOption();
}

const setPeer = async () => {
    const [oftConfig] = PublicKey.findProgramAddressSync([Buffer.from(OFT_SEED), tokenMint.toBuffer()], programId);
    const [peerAccounts] = PublicKey.findProgramAddressSync([Buffer.from(PEER_SEED), oftConfig.toBuffer(), new BN(peer.dstEid).toArrayLike(Buffer, 'be', 4)], programId);

    const transaction = new Transaction().add(
        await program.methods.setPeer({
            dstEid: peer.dstEid,
            peer: Array.from(peer.peerAddress)
        })
            .accounts({
                admin: adminKeypair.publicKey,
                peer: peerAccounts,
                oftConfig,
                systemProgram: SystemProgram.programId
            }).instruction()
    );

    const txHash = await sendAndConfirmTransaction(connection, transaction, [adminKeypair]);
    console.log('setPeerTxHash-> ', txHash);
}

const setOption = async () => {
    const [oftConfig] = PublicKey.findProgramAddressSync([Buffer.from(OFT_SEED), tokenMint.toBuffer()], programId);
    const [enforcedOptionAccounts] = PublicKey.findProgramAddressSync([Buffer.from(ENFORCED_OPTIONS_SEED), oftConfig.toBuffer(), new BN(peer.dstEid).toArrayLike(Buffer, 'be', 4)], programId);

    const transaction = new Transaction().add(
        await program.methods.setEnforcedOptions({
            dstEid: peer.dstEid,
            send: Buffer.from(Options.newOptions().addExecutorLzReceiveOption(200000, 0).toBytes()),
            sendAndCall: Buffer.from(Options.newOptions().addExecutorLzReceiveOption(200000, 0).toBytes()),
        })
            .accounts({
                admin: adminKeypair.publicKey,
                enforcedOptions: enforcedOptionAccounts,
                oftConfig,
                systemProgram: SystemProgram.programId
            }).instruction()
    );

    const txHash = await sendAndConfirmTransaction(connection, transaction, [adminKeypair]);
    console.log('setOptionTxHash-> ', txHash);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
