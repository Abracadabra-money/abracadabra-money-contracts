// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/MIMPreCrime.s.sol";
import {BoringOwnable} from "BoringSolidity/BoringOwnable.sol";
import {ERC20} from "BoringSolidity/ERC20.sol";
import {ILzApp, IPreCrimeView} from "interfaces/ILayerZero.sol";
import {IMintableBurnable} from "interfaces/IMintableBurnable.sol";
import {IAnyswapERC20} from "interfaces/IAnyswapERC20.sol";

interface IMainnetMIM {
    function mint(address _to, uint _amount) external;

    function burn(uint _amount) external;
}

contract MIMPrecrimeTest is BaseTest {
    uint constant ld2sdRate = 10 ** (18 - 8);
    address constant dead = 0x000000000000000000000000000000000000dEaD;

    mapping(uint => ILzApp) ofts;
    mapping(uint => PreCrimeView) precrimes;
    mapping(uint => BaseOFTV2View) oftViews;
    mapping(uint => uint) forkBlocks;
    mapping(uint => uint) forks;
    mapping(uint => IERC20) MIMs;
    mapping(uint => address) mimWhale;
    mapping(uint => address) mimMinters;

    uint[] chains = [
        ChainId.Mainnet,
        //ChainId.BSC,
        ChainId.Avalanche,
        ChainId.Polygon,
        ChainId.Arbitrum,
        ChainId.Optimism,
        ChainId.Fantom,
        ChainId.Moonriver
    ];

    uint[] lzChains = [
        LayerZeroChainId.Mainnet,
        //LayerZeroChainId.BSC,
        LayerZeroChainId.Avalanche,
        LayerZeroChainId.Polygon,
        LayerZeroChainId.Arbitrum,
        LayerZeroChainId.Optimism,
        LayerZeroChainId.Fantom,
        LayerZeroChainId.Moonriver
    ];

    uint originalMintedTotalSupply;

    function setUp() public override {
        super.setUp();

        forkBlocks[ChainId.Mainnet] = 17693923;
        //forkBlocks[ChainId.BSC] = 29964515;
        forkBlocks[ChainId.Avalanche] = 32604705;
        forkBlocks[ChainId.Polygon] = 45080516;
        forkBlocks[ChainId.Arbitrum] = 111229687;
        forkBlocks[ChainId.Optimism] = 106882972;
        forkBlocks[ChainId.Fantom] = 65806128;
        forkBlocks[ChainId.Moonriver] = 4672329;

        mimWhale[ChainId.Mainnet] = 0x5f0DeE98360d8200b20812e174d139A1a633EDd2;
        //mimWhale[ChainId.BSC] = 0x9d9bC38bF4A128530EA45A7d27D0Ccb9C2EbFaf6;
        mimWhale[ChainId.Avalanche] = 0xae64A325027C3C14Cf6abC7818aA3B9c07F5C799;
        mimWhale[ChainId.Polygon] = 0x7d477C61A3db268c31E4350C8613fF0e18A42c06;
        mimWhale[ChainId.Arbitrum] = 0x27807dD7ADF218e1f4d885d54eD51C70eFb9dE50;
        mimWhale[ChainId.Optimism] = 0x4217AA01360846A849d2A89809d450D10248B513;
        mimWhale[ChainId.Fantom] = 0x6f86e65b255c9111109d2D2325ca2dFc82456efc;
        mimWhale[ChainId.Moonriver] = 0x33882266ACC3a7Ab504A95FC694DA26A27e8Bd66;

        // Setup forks
        for (uint i = 0; i < chains.length; i++) {
            popAllPranks();
            forks[chains[i]] = fork(chains[i], forkBlocks[chains[i]]);

            MIMPreCrimeScript script = new MIMPreCrimeScript();
            script.setTesting(true);
            (PreCrimeView precrime, BaseOFTV2View oftView) = script.deploy();

            precrimes[block.chainid] = precrime;
            oftViews[block.chainid] = oftView;
            ofts[block.chainid] = ILzApp(oftView.oft());
            MIMs[block.chainid] = IERC20(toolkit.getAddress(block.chainid, "mim"));

            if (block.chainid != ChainId.Mainnet) {
                address[] memory minters = IAnyswapERC20(address(MIMs[block.chainid])).getAllMinters();

                for (uint j = 0; j < minters.length; j++) {
                    if (IAnyswapERC20(address(MIMs[block.chainid])).isMinter(minters[j])) {
                        mimMinters[block.chainid] = minters[j];
                    }
                }
            }
        }

        ////////////////////////////////////////////////////////////////////////////////////////////////
        // Since there might be pending bridge txs, we need to make sure the locked amount
        // on the mainnet contract is equivalent to the sum of the total supply of all other chains
        /// Make sure originalMintedTotalSupply == lockedAmount so we can test invariants correctly.
        for (uint i = 0; i < chains.length; i++) {
            if (chains[i] == ChainId.Mainnet) {
                continue;
            }
            vm.selectFork(forks[chains[i]]);
            originalMintedTotalSupply += oftViews[chains[i]].getCurrentState();
        }

        vm.selectFork(forks[ChainId.Mainnet]);

        uint lockedAmount = MIMs[ChainId.Mainnet].balanceOf(address(ofts[ChainId.Mainnet]));
        if (lockedAmount > originalMintedTotalSupply) {
            // burn the excess
            vm.prank(address(ofts[ChainId.Mainnet]));
            IMainnetMIM(address(MIMs[ChainId.Mainnet])).burn(lockedAmount - originalMintedTotalSupply);
        } else if (lockedAmount < originalMintedTotalSupply) {
            // mint the missing amount
            IMainnetMIM(address(MIMs[ChainId.Mainnet])).mint(address(ofts[ChainId.Mainnet]), originalMintedTotalSupply - lockedAmount);
        }
        //
        ////////////////////////////////////////////////////////////////////////////////////////////////

        assertEq(originalMintedTotalSupply, oftViews[ChainId.Mainnet].getCurrentState(), "total supply is not equal to the locked amount");

        for (uint i = 0; i < chains.length; i++) {
            vm.selectFork(forks[chains[i]]);

            uint16[] memory remoteChainIds = new uint16[](chains.length - 1);
            bytes32[] memory remotePrecrimeAddresses = new bytes32[](chains.length - 1);
            uint index = 0;

            for (uint j = 0; j < chains.length; j++) {
                if (chains[j] != chains[i]) {
                    remoteChainIds[index] = uint16(lzChains[j]);
                    remotePrecrimeAddresses[index] = bytes32(uint256(uint160(address(precrimes[chains[j]]))));
                    index++;
                }
            }

            PreCrimeView precrime = precrimes[chains[i]];

            pushPrank(precrime.owner());
            precrime.setRemotePrecrimeAddresses(remoteChainIds, remotePrecrimeAddresses);
            popPrank();
        }
    }

    /// forge-config: ci.fuzz.runs = 5000
    ///
    /// How does it works:
    ///
    /// Chains = [A,B,C]
    ///
    /// You have a series of transactions that are inbound for chainA
    ///
    /// tx1 = {src: B, dst; A, amount 100}
    /// tx2 = {src: C, dst: A, amount: 3}
    /// tx3 = {src: C, dst: A, amount: 50}
    ///
    ///
    /// packets = [tx1, tx2, tx3]
    ///
    ///
    /// results[0] = chainA.simulate(packets)
    /// results[1] = chainB.simulate([])
    /// results[2] = chainC.simulate([])
    ///
    /// chainA.precrime(packets, results)
    ///
    /// when crime is true it shouldn't burn when transfering from an altchain or transfering mim from
    /// the proxy when transfering from mainnet
    uint16 fromLzChainId;
    bytes32 srcAddress;
    uint simulationIndex;
    bool abort;

    function testPrecrime(uint fromChainId, uint toChainId, uint amount, bool crime) public {
        fromChainId = fromChainId % chains.length;
        toChainId = toChainId % chains.length;

        fromLzChainId = uint16(lzChains[fromChainId]);

        fromChainId = chains[fromChainId];
        toChainId = chains[toChainId];

        vm.assume(fromChainId != toChainId);

        vm.selectFork(forks[fromChainId]);
        amount = bound(amount, 0, _ld2sd(IERC20(address(MIMs[fromChainId])).balanceOf(mimWhale[fromChainId])));
        amount = bound(amount, 0, _sd2ld(type(uint64).max));
        (amount, ) = _removeDust(amount);

        console2.log("From chain: %s, to chain: %s, for amount %s", fromChainId, toChainId, amount);

        srcAddress = bytes32(uint256(uint160(address(ofts[fromChainId]))));

        bytes[] memory simulations = new bytes[](chains.length);
        simulationIndex = 0;
        abort = false;

        IPreCrimeView.Packet memory transferPacket;

        for (uint i = 0; i < chains.length; i++) {
            uint currentChain = chains[i];
            PreCrimeView precrimeView = precrimes[currentChain];

            vm.selectFork(forks[currentChain]);

            IPreCrimeView.Packet[] memory packets;

            // when crime is false, we need to burn from alt chain or remove mim from the proxy
            if (!crime && currentChain == fromChainId && amount > 0) {
                if (currentChain == ChainId.Mainnet) {
                    vm.prank(mimWhale[ChainId.Mainnet]);
                    ERC20(address(MIMs[ChainId.Mainnet])).transfer(address(ofts[ChainId.Mainnet]), _sd2ld(uint64(amount)));
                } else {
                    console2.log(_sd2ld(uint64(amount)));
                    vm.prank(mimMinters[currentChain]);
                    IMintableBurnable(address(MIMs[currentChain])).burn(mimWhale[currentChain], _sd2ld(uint64(amount)));
                }
            }

            if (currentChain == toChainId) {
                packets = new IPreCrimeView.Packet[](1);
                transferPacket = IPreCrimeView.Packet({
                    srcChainId: fromLzChainId,
                    srcAddress: srcAddress,
                    nonce: oftViews[toChainId].getInboundNonce(uint16(fromLzChainId)) + 1,
                    payload: abi.encodePacked(uint8(0), bytes32(0), _ld2sd(amount))
                });

                packets[0] = transferPacket;
            } else {
                packets = new IPreCrimeView.Packet[](0);
            }

            // when this revert, check reason to see if it's "ProxyOFTV2View: transfer amount exceeds locked amount"
            // otherwise that's an issue with the test or the codebase, in this case bubble up the revert message
            try precrimeView.simulate(packets) returns (uint16 code, bytes memory result) {
                assertEq(code, 0, string.concat("simulate failed with code ", vm.toString(code)));
                simulations[simulationIndex] = result;
                simulationIndex++;
            } catch (bytes memory reason) {
                // check reason if ErrTransferAmountExceedsLockedAmount()
                // otherwise bubble up the revert message
                if (keccak256(abi.encodeWithSignature("ErrTransferAmountExceedsLockedAmount()")) == keccak256(reason)) {
                    // validate if the amount is greater than the locked amount
                    vm.selectFork(forks[ChainId.Mainnet]);
                    uint lockedAmount = MIMs[ChainId.Mainnet].balanceOf(address(ofts[ChainId.Mainnet]));
                    assertGt(amount, lockedAmount, "amount is not greater than the locked amount");
                    abort = true;
                } else {
                    revert("unexpected revert message");
                }
            }
        }

        if (!abort) {
            IPreCrimeView.Packet[] memory packets = new IPreCrimeView.Packet[](1);
            packets[0] = transferPacket;

            // now that we have all the simulations, we can call `precrime` on the destination chain
            vm.selectFork(forks[toChainId]);
            (uint16 code, bytes memory reason) = precrimes[toChainId].precrime(packets, simulations);

            string memory reasonAsString;
            assembly {
                reasonAsString := reason
            }

            assertLe(code, 1, string.concat("precrime failed with code ", vm.toString(code), ": ", reasonAsString));

            // CODE_PRECRIME_FAILURE
            // Double check if the crime is real
            if (code == 1) {
                assertTrue(crime, "crime is not true, shouldn't happen");

                vm.selectFork(forks[ChainId.Mainnet]);
                uint lockedAmount = MIMs[ChainId.Mainnet].balanceOf(address(ofts[ChainId.Mainnet]));
                assertGt(originalMintedTotalSupply + _sd2ld(uint64(amount)), lockedAmount, "amount is not greater than the locked amount");
            }
        }
    }

    function _ld2sd(uint _amount) internal view virtual returns (uint64) {
        uint amountSD = _amount / ld2sdRate;
        require(amountSD <= type(uint64).max, "OFTCore: amountSD overflow");
        return uint64(amountSD);
    }

    function _sd2ld(uint64 _amountSD) internal view virtual returns (uint) {
        return _amountSD * ld2sdRate;
    }

    function _removeDust(uint _amount) internal view virtual returns (uint amountAfter, uint dust) {
        dust = _amount % ld2sdRate;
        amountAfter = _amount - dust;
    }
}
