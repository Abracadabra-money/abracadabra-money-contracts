import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { expect } from 'chai'
import { Contract, ContractFactory } from 'ethers'
import { deployments, ethers } from 'hardhat'

import { Options } from '@layerzerolabs/lz-v2-utilities'

describe('LZV2OFT Test', function () {
    // Constant representing a mock Endpoint ID for testing purposes
    const eidA = 1
    const eidB = 2
    // Declaration of variables to be used in the test suite
    let LZV2OFT: ContractFactory
    let EndpointV2Mock: ContractFactory
    let mintAuthA: SignerWithAddress
    let mintAuthB: SignerWithAddress
    let ownerA: SignerWithAddress
    let ownerB: SignerWithAddress
    let endpointOwner: SignerWithAddress
    let lzV2OFTA: Contract
    let lzV2OFTB: Contract
    let mockEndpointV2A: Contract
    let mockEndpointV2B: Contract

    // Before hook for setup that runs once before all tests in the block
    before(async function () {
        // Contract factory for our tested contract
        //
        // We are using a derived contract that exposes a mint() function for testing purposes
        LZV2OFT = await ethers.getContractFactory('LZV2OFTMock')

        // Fetching the first three signers (accounts) from Hardhat's local Ethereum network
        const signers = await ethers.getSigners()


        mintAuthA = signers.at(0)!
        mintAuthB = signers.at(1)!
        ownerA = signers.at(2)!
        ownerB = signers.at(3)!
        endpointOwner = signers.at(4)!

        // The EndpointV2Mock contract comes from @layerzerolabs/test-devtools-evm-hardhat package
        // and its artifacts are connected as external artifacts to this project
        //
        // Unfortunately, hardhat itself does not yet provide a way of connecting external artifacts,
        // so we rely on hardhat-deploy to create a ContractFactory for EndpointV2Mock
        //
        // See https://github.com/NomicFoundation/hardhat/issues/1040
        const EndpointV2MockArtifact = await deployments.getArtifact('EndpointV2Mock')
        EndpointV2Mock = new ContractFactory(EndpointV2MockArtifact.abi, EndpointV2MockArtifact.bytecode, endpointOwner)
    })

    // beforeEach hook for setup that runs before each test in the block
    beforeEach(async function () {
        // Deploying a mock LZEndpoint with the given Endpoint ID
        mockEndpointV2A = await EndpointV2Mock.deploy(eidA)
        mockEndpointV2B = await EndpointV2Mock.deploy(eidB)

        // Deploying two instances of LZV2OFT contract with different identifiers and linking them to the mock LZEndpoint
        lzV2OFTA = await LZV2OFT.deploy('aOFT', 'aOFT', mockEndpointV2A.address, mintAuthA.address)
        lzV2OFTB = await LZV2OFT.deploy('bOFT', 'bOFT', mockEndpointV2B.address, mintAuthB.address)

        // Setting destination endpoints in the LZEndpoint mock for each LZV2OFT instance
        await mockEndpointV2A.setDestLzEndpoint(lzV2OFTB.address, mockEndpointV2B.address)
        await mockEndpointV2B.setDestLzEndpoint(lzV2OFTA.address, mockEndpointV2A.address)

        // Setting each LZV2OFT instance as a peer of the other in the mock LZEndpoint
        await lzV2OFTA.connect(mintAuthA).setPeer(eidB, ethers.utils.zeroPad(lzV2OFTB.address, 32))
        await lzV2OFTB.connect(mintAuthB).setPeer(eidA, ethers.utils.zeroPad(lzV2OFTA.address, 32))
    })

    // A test case to verify token transfer functionality
    it('should send a token from A address to B address via each OFT', async function () {
        // Minting an initial amount of tokens to ownerA's address in the lzV2OFTA contract
        const initialAmount = ethers.utils.parseEther('100')
        await lzV2OFTA.connect(mintAuthA).mint(ownerA.address, initialAmount)

        // Defining the amount of tokens to send and constructing the parameters for the send operation
        const tokensToSend = ethers.utils.parseEther('1')

        // Defining extra message execution options for the send operation
        const options = Options.newOptions().addExecutorLzReceiveOption(200000, 0).toHex().toString()

        const sendParam = [
            eidB,
            ethers.utils.zeroPad(ownerB.address, 32),
            tokensToSend,
            tokensToSend,
            options,
            '0x',
            '0x',
        ]

        // Fetching the native fee for the token send operation
        const [nativeFee] = await lzV2OFTA.quoteSend(sendParam, false)

        // Executing the send operation from lzV2OFTA contract
        await lzV2OFTA.connect(ownerA).send(sendParam, [nativeFee, 0], ownerA.address, { value: nativeFee })

        // Fetching the final token balances of ownerA and ownerB
        const finalBalanceA = await lzV2OFTA.balanceOf(ownerA.address)
        const finalBalanceB = await lzV2OFTB.balanceOf(ownerB.address)

        // Asserting that the final balances are as expected after the send operation
        expect(finalBalanceA).eql(initialAmount.sub(tokensToSend))
        expect(finalBalanceB).eql(tokensToSend)
    })
})
