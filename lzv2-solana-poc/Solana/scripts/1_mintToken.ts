import accounts from "./getAccounts";
import {
    Keypair,
    Transaction,
    SystemProgram,
    sendAndConfirmTransaction
} from "@solana/web3.js"
import {
    getMintLen,
    TOKEN_PROGRAM_ID,
    createInitializeMintInstruction,
    createAssociatedTokenAccountInstruction,
    getAssociatedTokenAddressSync,
    createMintToInstruction
} from "@solana/spl-token"

const { connection, adminKeypair, userKeypair, } = accounts;
const mintKp = Keypair.generate();

async function main() {
    await mintSpl();
}

async function mintSpl(decimals = 6, initialTokenAmount = 100_000_000) {
    const userATA = getAssociatedTokenAddressSync(mintKp.publicKey, userKeypair.publicKey);

    const minimumBalanceForMint = await connection.getMinimumBalanceForRentExemption(getMintLen([]));
    const transaction = new Transaction().add(
        SystemProgram.createAccount({
            fromPubkey: adminKeypair.publicKey,
            newAccountPubkey: mintKp.publicKey,
            space: getMintLen([]),
            lamports: minimumBalanceForMint,
            programId: TOKEN_PROGRAM_ID,
        }),
        createInitializeMintInstruction(
            mintKp.publicKey, // mint public key
            decimals, // decimals
            adminKeypair.publicKey, // mint authority
            null, // freeze authority (not used here)
            TOKEN_PROGRAM_ID, // token program id
        ),
        createAssociatedTokenAccountInstruction(
            adminKeypair.publicKey,
            userATA,
            userKeypair.publicKey,
            mintKp.publicKey
        ),
        createMintToInstruction(
            mintKp.publicKey,
            userATA,
            adminKeypair.publicKey,
            initialTokenAmount
        ),
    );
    const txHash = await sendAndConfirmTransaction(connection, transaction, [adminKeypair, mintKp]);
    console.log('txHash-> ', txHash);

    console.log('You need to update .env variables:');
    console.info('SOLANA_SPL_TOKEN_ADDRESS=', mintKp.publicKey.toString());
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
