// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/PreCrime.s.sol";
import {ILzApp} from "interfaces/ILzApp.sol";

contract PrecrimeTest is BaseTest {
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

    function test() public {}
}
