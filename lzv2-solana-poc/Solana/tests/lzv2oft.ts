import dotenv from 'dotenv'
import path from 'path'
import { AnchorProvider, Program, BN, web3 } from "@coral-xyz/anchor";
import {
  Keypair,
  PublicKey,
  Transaction,
  sendAndConfirmTransaction,
  SystemProgram,
  Connection,
  clusterApiUrl,
  ComputeBudgetProgram,
  TransactionInstruction
} from '@solana/web3.js';
import {
  AuthorityType,
  TOKEN_PROGRAM_ID,
  createInitializeMintInstruction,
  createSetAuthorityInstruction,
  createAssociatedTokenAccountInstruction,
  getMintLen,
  getAssociatedTokenAddressSync,
  createMintToInstruction
} from '@solana/spl-token';
import { Lzv2oft as Lzv2oftIdl, IDL } from "../target/types/lzv2oft";
import { bs58 } from '@coral-xyz/anchor/dist/cjs/utils/bytes';
import {
  LZ_RECEIVE_TYPES_SEED,
  OFT_SEED,
  OAPP_SEED,
  PEER_SEED,
  ENFORCED_OPTIONS_SEED,
  EventPDADeriver,
  PENDING_NONCE_SEED,
  RECEIVE_LIBRARY_CONFIG_SEED,
  EndpointProgram,
  ULN_SEED,
  SimpleMessageLibProgram,
  getSimpleMessageLibProgramId,
  SEND_LIBRARY_CONFIG_SEED,
  MESSAGE_LIB_SEED,
  NONCE_SEED,
  ENDPOINT_SEED,
  getEndpointProgramId,
  getExecutorProgramId,
  getPricefeedProgramId,
  getDVNProgramId,
  getULNProgramId,
  ExecutorPDADeriver,
  PriceFeedPDADeriver,
  DVNDeriver,
  UlnPDADeriver
} from '@layerzerolabs/lz-solana-sdk-v2';
import { EndpointId } from '@layerzerolabs/lz-definitions'
import { addressToBytes32, Options } from '@layerzerolabs/lz-v2-utilities';

dotenv.config({ path: path.resolve(__dirname, '../../.env') });

describe("lzv2oft", () => {
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
  // const simpleMessageLibProgramId = getSimpleMessageLibProgramId("solana-testnet");
  const ulnProgramId = getULNProgramId("solana-mainnet");


  const evmUser = addressToBytes32(process.env.EVM_USER_PUB_KEY);
  const evmOftAddress = addressToBytes32(process.env.ARBITRUM_SEPOLIA_OFT_ADDRESS);

  if (process.env.SOLANA_TOKEN_KEYPAIR === '') {
    const mintKp = Keypair.generate();
    const [oftConfig] = PublicKey.findProgramAddressSync([Buffer.from(OFT_SEED), mintKp.publicKey.toBuffer()], programId);

    console.log('You need to update .env variables and run test again.');
    console.info('SOLANA_TOKEN_KEYPAIR=', bs58.encode(mintKp.secretKey));
    console.info('SOLANA_TESTNET_OFT_ADDRESS=', oftConfig.toBase58());
    return;
  }

  const mintKp = Keypair.fromSecretKey(bs58.decode(process.env.SOLANA_TOKEN_KEYPAIR));
  const userATA = getAssociatedTokenAddressSync(mintKp.publicKey, userKeypair.publicKey);
  const [oftConfig] = PublicKey.findProgramAddressSync([Buffer.from(OFT_SEED), mintKp.publicKey.toBuffer()], programId);

  console.log("mintKp->", mintKp.secretKey.toString(), "mintPubkey", mintKp.publicKey.toString(), "oftConfig", oftConfig.toString());

  const [lzReceiveTypesAccounts] = PublicKey.findProgramAddressSync([Buffer.from(LZ_RECEIVE_TYPES_SEED), oftConfig.toBuffer()], programId);
  const [oappRegister] = PublicKey.findProgramAddressSync([Buffer.from(OAPP_SEED), oftConfig.toBuffer()], endpointProgramId);

  const peer = { dstEid: EndpointId.ARBSEP_V2_TESTNET, peerAddress: addressToBytes32(process.env.ARBITRUM_SEPOLIA_OFT_ADDRESS) };

  const [sendLibraryConfig] = PublicKey.findProgramAddressSync([Buffer.from(SEND_LIBRARY_CONFIG_SEED), oftConfig.toBuffer(), new BN(peer.dstEid).toArrayLike(Buffer, 'be', 4)], endpointProgramId);
  const [receiveLibraryConfig] = PublicKey.findProgramAddressSync([Buffer.from(RECEIVE_LIBRARY_CONFIG_SEED), oftConfig.toBuffer(), new BN(peer.dstEid).toArrayLike(Buffer, 'be', 4)], endpointProgramId);
  const [defaultSendLibraryConfig] = PublicKey.findProgramAddressSync([Buffer.from(SEND_LIBRARY_CONFIG_SEED), new BN(peer.dstEid).toArrayLike(Buffer, 'be', 4)], endpointProgramId);
  const sendLibrary = PublicKey.default;
  const [nonce] = PublicKey.findProgramAddressSync([Buffer.from(NONCE_SEED), oftConfig.toBuffer(), new BN(peer.dstEid).toArrayLike(Buffer, 'be', 4), evmOftAddress], endpointProgramId);
  const [endpoint] = PublicKey.findProgramAddressSync([Buffer.from(ENDPOINT_SEED)], endpointProgramId);
  const [pendingInboundNonce] = PublicKey.findProgramAddressSync([Buffer.from(PENDING_NONCE_SEED), oftConfig.toBuffer(), new BN(peer.dstEid).toArrayLike(Buffer, 'be', 4), evmOftAddress], endpointProgramId);
  const [messageLib] = PublicKey.findProgramAddressSync([Buffer.from(MESSAGE_LIB_SEED)], ulnProgramId);
  const [messageLibInfo] = PublicKey.findProgramAddressSync([Buffer.from(MESSAGE_LIB_SEED), messageLib.toBuffer()], ulnProgramId);

  const [peerAccounts] = PublicKey.findProgramAddressSync([Buffer.from(PEER_SEED), oftConfig.toBuffer(), new BN(peer.dstEid).toArrayLike(Buffer, 'be', 4)], programId);
  const [enforcedOptionAccounts] = PublicKey.findProgramAddressSync([Buffer.from(ENFORCED_OPTIONS_SEED), oftConfig.toBuffer(), new BN(peer.dstEid).toArrayLike(Buffer, 'be', 4)], programId);

  const [ulnPda] = PublicKey.findProgramAddressSync([Buffer.from(ULN_SEED)], ulnProgramId);

  const OFT_DECIMALS = 6;
  const initialTokenAmount = 100_000_000; // 100
  const amountToSend = 5_000_000;

  it("Initialize new spl token mint", async () => {
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
        OFT_DECIMALS, // decimals
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

    // Send the transaction to create the mint
    const txHash = await sendAndConfirmTransaction(connection, transaction, [adminKeypair, mintKp]);
    console.log('txHash-> ', txHash);
  });

  it("set mint auth to oft_config and init oft_config", async () => {
    const transaction = new Transaction().add(
      createSetAuthorityInstruction(
        mintKp.publicKey,
        adminKeypair.publicKey,
        AuthorityType.MintTokens,
        oftConfig,
      ),
      await program.methods.initOft({
        admin: adminKeypair.publicKey,
        sharedDecimals: OFT_DECIMALS,
        endpointProgram: endpointProgramId,
        mintAuthority: null
      }).accounts({
        payer: adminKeypair.publicKey,
        oftConfig,
        lzReceiveTypesAccounts,
        tokenMint: mintKp.publicKey,
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

    console.log('txHash-> ', txHash);

    console.log('init oft_config. You need to update .env variable like below:');
    console.log(`SOLANA_TESTNET_OFT_ADDRESS=`, oftConfig.toString());
  });

  it("init send library", async () => {
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
    console.log("txInitSendLibrary = ", txInitSendLibrary)
  })


  it("init receive library", async () => {
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
    console.log("initReceiveLibTx = ", initReceiveLibTx)
  })

  it("init nonce", async () => {
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
    console.log('txInitNonce', txInitNonce);
  })

  it("set peer", async () => {
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
    console.log('txHash-> ', txHash);
  });

  it("createOption", async () => {
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
    console.log('txHash-> ', txHash);
  });

  it("send token", async () => {
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
      tokenMint: mintKp.publicKey,
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
    console.log('txHash-> ', txHash);
  });
});
