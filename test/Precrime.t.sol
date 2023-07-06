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
        }
    }

    /// forge-config: ci.fuzz.runs = 50000
    function testPrecrime(uint fromChainId, uint toChainId, uint amount) public {
        fromChainId = fromChainId % chains.length;
        toChainId = toChainId % chains.length;

        uint16 fromLzChainId = uint16(lzChains[fromChainId]);

        fromChainId = chains[fromChainId];
        toChainId = chains[toChainId];

        vm.assume(fromChainId != toChainId);

        console2.log("From chain: %s, to chain: %s, for amount %s", fromChainId, toChainId, amount);

        bytes32 srcAddress = bytes32(uint256(uint160(address(ofts[fromChainId]))));

        // retrieve the destination chain expected nonce
        vm.selectFork(forks[toChainId]);
        uint64 nonce = oftViews[toChainId].getInboundNonce(uint16(fromLzChainId)) + 1;

        // assumes the LZ relayer is calling `simulate` on every chain Precrime contract
        for (uint i = 0; i < chains.length; i++) {
            if (chains[i] == fromChainId) {
                continue;
            }

            PreCrimeView precrimeView = precrimes[chains[i]];

            // only simulate with one packet. But in production this could be up to `_maxBatchSize`
            vm.selectFork(forks[chains[i]]);

            IPreCrimeView.Packet[] memory packets = new IPreCrimeView.Packet[](1);
            packets[0] = IPreCrimeView.Packet({
                srcChainId: fromLzChainId,
                srcAddress: srcAddress,
                nonce: nonce,
                payload: abi.encodePacked(uint8(0), bytes32(0), _ld2sd(amount))
            });

            (uint16 code, bytes memory result) = precrimeView.simulate(packets);

            console.log("simulate result: %s, simulate result:", code);
            console.logBytes(result);
        }
    }

    function _ld2sd(uint _amount) internal view virtual returns (uint64) {
        uint amountSD = _amount / ld2sdRate;
        require(amountSD <= type(uint64).max, "OFTCore: amountSD overflow");
        return uint64(amountSD);
    }
}
