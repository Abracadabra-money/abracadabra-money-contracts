// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "solady/utils/LibString.sol";
import "./Toolkit.sol";
import {ArbSysMock} from "./mocks/ArbSysMock.sol";

abstract contract BaseTest is Test {
    using LibString for string;
    Toolkit internal toolkit = getToolkit();

    address payable internal alice;
    address payable internal bob;
    address payable internal carol;
    address[] pranks;

    ArbSysMock arbsys;

    modifier onlyProfile(string memory expectedProfile) {
        try vm.envString("FOUNDRY_PROFILE") returns (string memory currentProfile) {
            if (keccak256(abi.encodePacked(currentProfile)) == keccak256(abi.encodePacked(expectedProfile))) {
                _;
                return;
            }
        } catch {}

        console2.log("[Skipped] %s only", expectedProfile);
    }

    function setUp() public virtual {
        popAllPranks();

        alice = createUser("alice", address(0x1), 100 ether);
        bob = createUser("bob", address(0x2), 100 ether);
        carol = createUser("carol", address(0x3), 100 ether);

        if (block.chainid == ChainId.Arbitrum) {
            arbsys = new ArbSysMock();
            vm.etch(address(0x0000000000000000000000000000000000000064), address(arbsys).code);
        }
    }

    function createUser(string memory label, address account, uint256 amount) internal returns (address payable) {
        vm.deal(account, amount);
        vm.label(account, label);
        return payable(account);
    }

    function advanceBlocks(uint256 delta) internal returns (uint256 blockNumber) {
        blockNumber = block.number + delta;
        vm.roll(blockNumber);
    }

    function advanceTime(uint256 delta) internal returns (uint256 timestamp) {
        timestamp = block.timestamp + delta;
        vm.warp(timestamp);
    }

    function pushPrank(address account) public {
        if (pranks.length > 0) {
            vm.stopPrank();
        }
        pranks.push(account);
        vm.startPrank(account);
    }

    function popPrank() public {
        if (pranks.length > 0) {
            vm.stopPrank();
            pranks.pop();

            if (pranks.length > 0) {
                vm.startPrank(pranks[pranks.length - 1]);
            }
        }
    }

    function popAllPranks() public {
        while (pranks.length > 0) {
            popPrank();
        }
    }

    function fork(uint256 chainId, uint256 blockNumber) internal returns (uint256) {
        string memory rpcUrlEnvVar = string.concat(toolkit.getChainName(chainId).upper(), "_RPC_URL");

        if (blockNumber == Block.Latest) {
            return vm.createSelectFork(vm.envString(rpcUrlEnvVar));
        }
        return vm.createSelectFork(vm.envString(rpcUrlEnvVar), blockNumber);
    }
}