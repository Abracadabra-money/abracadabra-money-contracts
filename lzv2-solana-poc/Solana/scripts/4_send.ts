import accounts from "./getAccounts";
import { BN } from "@coral-xyz/anchor"
import {
    PublicKey,
    Transaction,
    SystemProgram,
    sendAndConfirmTransaction,
    ComputeBudgetProgram
} from "@solana/web3.js"
import {
    TOKEN_PROGRAM_ID,
    getAssociatedTokenAddressSync,
} from "@solana/spl-token"
import {
    SEND_LIBRARY_CONFIG_SEED,
    MESSAGE_LIB_SEED,
    OFT_SEED,
    PEER_SEED,
    ENFORCED_OPTIONS_SEED,
    ENDPOINT_SEED,
    NONCE_SEED,
    ULN_SEED,
    EndpointProgram,
    EventPDADeriver,
    UlnPDADeriver,
    ExecutorPDADeriver,
    PriceFeedPDADeriver,
    DVNDeriver
} from '@layerzerolabs/lz-solana-sdk-v2';
import { Options } from '@layerzerolabs/lz-v2-utilities';

const { connection, programId, program, tokenMint, userKeypair, peer, endpointProgramId, evmUser, sendLibraryProgram, ulnProgramId, evmOftAddress, executorProgramId, priceFeeProgramId, dvnProgramId } = accounts;

const main = async () => {
    await send();
}

const send = async (amountToSend = 5_000_000) => {
    const [oftConfig] = PublicKey.findProgramAddressSync([Buffer.from(OFT_SEED), tokenMint.toBuffer()], programId);
    const [defaultSendLibraryConfig] = PublicKey.findProgramAddressSync([Buffer.from(SEND_LIBRARY_CONFIG_SEED), new BN(peer.dstEid).toArrayLike(Buffer, 'be', 4)], endpointProgramId);
    const [peerAccounts] = PublicKey.findProgramAddressSync([Buffer.from(PEER_SEED), oftConfig.toBuffer(), new BN(peer.dstEid).toArrayLike(Buffer, 'be', 4)], programId);
    const [enforcedOptionAccounts] = PublicKey.findProgramAddressSync([Buffer.from(ENFORCED_OPTIONS_SEED), oftConfig.toBuffer(), new BN(peer.dstEid).toArrayLike(Buffer, 'be', 4)], programId);
    const [sendLibraryConfig] = PublicKey.findProgramAddressSync([Buffer.from(SEND_LIBRARY_CONFIG_SEED), oftConfig.toBuffer(), new BN(peer.dstEid).toArrayLike(Buffer, 'be', 4)], endpointProgramId);
    const [endpoint] = PublicKey.findProgramAddressSync([Buffer.from(ENDPOINT_SEED)], endpointProgramId);
    const [nonce] = PublicKey.findProgramAddressSync([Buffer.from(NONCE_SEED), oftConfig.toBuffer(), new BN(peer.dstEid).toArrayLike(Buffer, 'be', 4), evmOftAddress], endpointProgramId);
    const [ulnPda] = PublicKey.findProgramAddressSync([Buffer.from(ULN_SEED)], ulnProgramId);

    const userATA = getAssociatedTokenAddressSync(tokenMint, userKeypair.publicKey);

    const options = Options.newOptions().addExecutorLzReceiveOption(600000, 0).toBytes();
    const res = await EndpointProgram.accounts.SendLibraryConfig.fromAccountAddress(connection, defaultSendLibraryConfig);
    const [sendLibraryInfo] = PublicKey.findProgramAddressSync([Buffer.from(MESSAGE_LIB_SEED), res.messageLib.toBuffer()], endpointProgramId);

    // const nativeFeeTx = await program.methods.quote({
    //   dstEid: peer.dstEid,
    //   to: Array.from(evmUser),
    //   amountLd: new BN(amountToSend),
    //   minAmountLd: new BN(amountToSend),
    //   options: Buffer.from(options),
    //   composeMsg: Buffer.from(composedMessage),
    //   payInLzToken: false,
    // }).accounts({
    //   oftConfig,
    //   peer: peerAccounts,
    //   enforcedOptions: enforcedOptionAccounts,
    //   tokenMint: mintKp.publicKey
    // }).remainingAccounts([
    //   {
    //     pubkey: sendLibrary,
    //     isSigner: false,
    //     isWritable: false,
    //   },
    //   {
    //     pubkey: sendLibraryConfig,
    //     isSigner: false,
    //     isWritable: false,
    //   },
    //   {
    //     pubkey: defaultSendLibraryConfig,
    //     isSigner: false,
    //     isWritable: false,
    //   },
    //   {
    //     pubkey: sendLibraryInfo,
    //     isSigner: false,
    //     isWritable: false,
    //   },
    //   {
    //     pubkey: endpoint,
    //     isSigner: false,
    //     isWritable: false,
    //   },
    //   {
    //     pubkey: nonce,
    //     isSigner: false,
    //     isWritable: false,
    //   },
    // ]).transaction();

    // const nativeFeeTxHash = await sendAndConfirmTransaction(connection, nativeFeeTx, [adminKeypair]);
    // const nativefeeTxData = await connection.getTransaction(nativeFeeTxHash, { commitment: "confirmed" });
    // console.log(nativefeeTxData);
    const transaction = new Transaction()
    transaction.add(ComputeBudgetProgram.setComputeUnitLimit({ units: 600000 }))

    transaction.add(await program.methods.send({
      dstEid: peer.dstEid,
      to: Array.from(evmUser),
      amountLd: new BN(amountToSend),
      minAmountLd: new BN(amountToSend),
      options: Buffer.from(options),
      composeMsg: Buffer.from(""),
      nativeFee: new BN(3_000_000_000),
      lzTokenFee: new BN(0),
    }).accounts({
      signer: userKeypair.publicKey,
      peer: peerAccounts,
      enforcedOptions: enforcedOptionAccounts,
      oftConfig,
      tokenSource: userATA,
      tokenMint: tokenMint,
      tokenProgram: TOKEN_PROGRAM_ID,
      tokenEscrow: null
    }).remainingAccounts([
      {
        pubkey: endpointProgramId,
        isSigner: false,
        isWritable: true,
      },
      {
        pubkey: oftConfig,
        isSigner: false,
        isWritable: true,
      },
      {
        pubkey: sendLibraryProgram,
        isSigner: false,
        isWritable: true,
      },
      {
        pubkey: sendLibraryConfig,
        isSigner: false,
        isWritable: true,
      },
      {
        pubkey: defaultSendLibraryConfig,
        isSigner: false,
        isWritable: true,
      },
      {
        pubkey: sendLibraryInfo,
        isSigner: false,
        isWritable: true,
      },
      {
        pubkey: endpoint,
        isSigner: false,
        isWritable: true,
      },
      {
        pubkey: nonce,
        isSigner: false,
        isWritable: true,
      },
      {
        pubkey: new EventPDADeriver(endpointProgramId).eventAuthority()[0],
        isSigner: false,
        isWritable: true,
      },
      {
        pubkey: endpointProgramId,
        isSigner: false,
        isWritable: true
      },
      {
        pubkey: ulnPda,
        isSigner: false,
        isWritable: true
      },
      {
        pubkey: new UlnPDADeriver(sendLibraryProgram).sendConfig(peer.dstEid, oftConfig)[0],
        isSigner: false,
        isWritable: true
      },
      {
        pubkey: new UlnPDADeriver(sendLibraryProgram).defaultSendConfig(peer.dstEid)[0],
        isSigner: false,
        isWritable: true
      },
      {
        pubkey: userKeypair.publicKey,
        isSigner: false,
        isWritable: true
      },
      {
        pubkey: userKeypair.publicKey,
        isSigner: false,
        isWritable: true
      },
      {
        pubkey: SystemProgram.programId,
        isSigner: false,
        isWritable: true
      },
      {
        pubkey: new EventPDADeriver(sendLibraryProgram).eventAuthority()[0],
        isSigner: false,
        isWritable: true,
      },
      {
        pubkey: sendLibraryProgram,
        isSigner: false,
        isWritable: true,
      },
      {
        pubkey: executorProgramId,
        isSigner: false,
        isWritable: true
      },
      {
        pubkey: new ExecutorPDADeriver(executorProgramId).config()[0],
        isSigner: false,
        isWritable: true,
      },
      {
        pubkey: priceFeeProgramId,
        isSigner: false,
        isWritable: true
      },
      {
        pubkey: new PriceFeedPDADeriver(priceFeeProgramId).priceFeed()[0],
        isSigner: false,
        isWritable: true
      },
      {
        pubkey: dvnProgramId,
        isSigner: false,
        isWritable: true
      },
      {
        pubkey: new DVNDeriver(dvnProgramId).config()[0],
        isSigner: false,
        isWritable: true
      },
      {
        pubkey: priceFeeProgramId,
        isSigner: false,
        isWritable: true
      },
      {
        pubkey: new PriceFeedPDADeriver(priceFeeProgramId).priceFeed()[0],
        isSigner: false,
        isWritable: true
      },
    ]).instruction());

    const txHash = await sendAndConfirmTransaction(connection, transaction, [userKeypair]);
    console.log('sendTxHash-> ', txHash);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});