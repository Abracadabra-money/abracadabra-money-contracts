// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "@solady/utils/LibString.sol";
import "./Toolkit.sol";
import {ArbSysMock} from "./mocks/ArbSysMock.sol";
import {BlastMock, BlastPointsMock} from "./mocks/BlastMock.sol";

abstract contract BaseTest is Test {
    using LibString for string;
    Toolkit internal toolkit = getToolkit();

    address payable internal alice;
    address payable internal bob;
    address payable internal carol;
    address[] pranks;

    modifier onlyProfile(string memory expectedProfile) {
        if (isProfile(expectedProfile)) {
            _;
            return;
        }

        vm.skip(true);
    }

    function setUp() public virtual {
        setUpNoMocks();

        if (block.chainid == ChainId.Arbitrum) {
            vm.etch(address(0x0000000000000000000000000000000000000064), address(new ArbSysMock()).code);
        } else if (block.chainid == ChainId.Blast) {
            vm.etch(address(0x4300000000000000000000000000000000000002), address(new BlastMock()).code);
            vm.etch(toolkit.getAddress(block.chainid, "blastPoints"), address(new BlastPointsMock()).code);
            vm.allowCheatcodes(address(0x4300000000000000000000000000000000000002));
        }
    }

    function setUpNoMocks() public virtual {
        popAllPranks();

        alice = createUser("alice", address(0x1), 100 ether);
        bob = createUser("bob", address(0x2), 100 ether);
        carol = createUser("carol", address(0x3), 100 ether);
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

    function isValidFuzzAddress(address account) internal view returns (bool) {
        return account.code.length == 0 && account != address(0);
    }

    function fork(uint256 chainId, uint256 blockNumber) internal returns (uint256 forkId) {
        string memory rpcUrlEnvVar = string.concat(toolkit.getChainName(chainId).upper(), "_RPC_URL");
        string memory rpcUrl = vm.envString(rpcUrlEnvVar);

        if (blockNumber == Block.Latest) {
            try vm.createSelectFork(rpcUrl) returns (uint256 id) {
                forkId = id;
            } catch {
                revert(string.concat("Failed to create fork for ", rpcUrlEnvVar, " at latest block"));
            }
        } else {
            try vm.createSelectFork(rpcUrl, blockNumber) returns (uint256 id) {
                forkId = id;
            } catch {
                revert(string.concat("Failed to create fork for ", rpcUrlEnvVar, " at block ", vm.toString(blockNumber)));
            }
        }

        assertEq(block.chainid, chainId, "ChainId mismatch");
    }

    function skipIfNotProfile(string memory expectedProfile) public {
        if (!isProfile(expectedProfile)) {
            vm.skip(true);
        }
    }

    function isProfile(string memory expectedProfile) public view returns (bool found) {
        try vm.envString("FOUNDRY_PROFILE") returns (string memory currentProfile) {
            found = keccak256(abi.encodePacked(currentProfile)) == keccak256(abi.encodePacked(expectedProfile));
        } catch {}
    }
}
