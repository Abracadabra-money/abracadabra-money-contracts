// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/PreCrime.s.sol";
import {ILzApp} from "interfaces/ILzApp.sol";
import {IPreCrimeView} from "interfaces/IPreCrimeView.sol";

contract PrecrimeTest is BaseTest {
    uint constant ld2sdRate = 10 ** (18 - 8);

    mapping(uint => ILzApp) ofts;
    mapping(uint => PreCrimeView) precrimes;
    mapping(uint => BaseOFTV2View) oftViews;
    mapping(uint => uint) forkBlocks;
    mapping(uint => uint) forks;
    mapping(uint => IERC20) MIMs;

    uint[] chains = [
        ChainId.Mainnet,
        ChainId.BSC,
        ChainId.Avalanche,
        ChainId.Polygon,
        ChainId.Arbitrum,
        ChainId.Optimism,
        ChainId.Fantom,
        ChainId.Moonriver
    ];

    uint[] lzChains = [
        LayerZeroChainId.Mainnet,
        LayerZeroChainId.BSC,
        LayerZeroChainId.Avalanche,
        LayerZeroChainId.Polygon,
        LayerZeroChainId.Arbitrum,
        LayerZeroChainId.Optimism,
        LayerZeroChainId.Fantom,
        LayerZeroChainId.Moonriver
    ];

    function setUp() public override {
        super.setUp();

        forkBlocks[ChainId.Mainnet] = 17632247;
        forkBlocks[ChainId.BSC] = 29715523;
        forkBlocks[ChainId.Avalanche] = 32236294;
        forkBlocks[ChainId.Polygon] = 44737087;
        forkBlocks[ChainId.Arbitrum] = 108318639;
        forkBlocks[ChainId.Optimism] = 106508333;
        forkBlocks[ChainId.Fantom] = 65194263;
        forkBlocks[ChainId.Moonriver] = 4610642;

        // Setup forks
        for (uint i = 0; i < chains.length; i++) {
            popAllPranks();
            forks[chains[i]] = fork(chains[i], forkBlocks[chains[i]]);

            PreCrimeScript script = new PreCrimeScript();
            script.setTesting(true);
            (PreCrimeView precrime, BaseOFTV2View oftView) = script.deploy();

            precrimes[block.chainid] = precrime;
            oftViews[block.chainid] = oftView;
            ofts[block.chainid] = ILzApp(oftView.oft());
            MIMs[block.chainid] = IERC20(constants.getAddress(block.chainid, "mim"));
        }

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
    function testPrecrime(uint fromChainId, uint toChainId, uint amount) public {
        amount = bound(amount, 0, _sd2ld(type(uint64).max));
        (amount, ) = _removeDust(amount);

        fromChainId = fromChainId % chains.length;
        toChainId = toChainId % chains.length;

        uint16 fromLzChainId = uint16(lzChains[fromChainId]);

        fromChainId = chains[fromChainId];
        toChainId = chains[toChainId];

        vm.assume(fromChainId != toChainId);

        console2.log("From chain: %s, to chain: %s, for amount %s", fromChainId, toChainId, amount);

        bytes32 srcAddress = bytes32(uint256(uint160(address(ofts[fromChainId]))));

        IPreCrimeView.Packet[] memory packets = new IPreCrimeView.Packet[](1);

        // assumes the LZ relayer is calling `simulate` on every chain Precrime contract
        for (uint i = 0; i < chains.length; i++) {
            if (chains[i] == fromChainId) {
                continue;
            }

            // only simulate with one packet. But in production this could be up to `_maxBatchSize`
            vm.selectFork(forks[chains[i]]);
            PreCrimeView precrimeView = precrimes[chains[i]];

            packets[0] = IPreCrimeView.Packet({
                srcChainId: fromLzChainId,
                srcAddress: srcAddress,
                nonce: oftViews[chains[i]].getInboundNonce(uint16(fromLzChainId)) + 1,
                payload: abi.encodePacked(uint8(0), bytes32(0), _ld2sd(amount))
            });

            // when this revert, check reason to see if it's "ProxyOFTV2View: transfer amount exceeds locked amount"
            // otherwise that's an issue with the test or the codebase, in this case bubble up the revert message
            try precrimeView.simulate(packets) returns (uint16 code, bytes memory result) {
                assertEq(code, 0, string.concat("simulate failed with code ", vm.toString(code)));
                //simulations[i] = abi.encode(code, result);
            } catch (bytes memory reason) {
                // check reason if ErrTransferAmountExceedsLockedAmount()
                // otherwise bubble up the revert message
                if (keccak256(abi.encodeWithSignature("ErrTransferAmountExceedsLockedAmount()")) == keccak256(reason)) {
                    // validate if the amount is greater than the locked amount
                    vm.selectFork(forks[ChainId.Mainnet]);
                    uint lockedAmount = MIMs[ChainId.Mainnet].balanceOf(address(ofts[ChainId.Mainnet]));
                    assertGt(amount, lockedAmount, "amount is not greater than the locked amount");
                } else {
                    revert("unexpected revert message");
                }
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
