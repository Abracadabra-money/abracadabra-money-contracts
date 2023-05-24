// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./Constants.sol";

abstract contract BaseTest is Test {
    Constants internal constants;

    address payable internal deployer;
    address payable internal alice;
    address payable internal bob;
    address payable internal carol;
    address[] pranks;

    function setUp() public virtual {
        popAllPranks();

        deployer = payable(tx.origin);
        vm.deal(deployer, 100 ether);
        vm.label(deployer, "deployer");

        alice = createUser("alice", address(0x1), 100 ether);
        bob = createUser("bob", address(0x2), 100 ether);
        carol = createUser("carol", address(0x3), 100 ether);

        constants = new Constants(vm);
        excludeContract(address(constants));
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
        while(pranks.length > 0) {
            popPrank();
        }
    }

    function fork(uint256 chainId, uint256 blockNumber) internal returns (uint256) {
        if(chainId == ChainId.Mainnet) {
            return forkMainnet(blockNumber);
        }
        if(chainId == ChainId.BSC) {
            return forkBSC(blockNumber);
        }
        if(chainId == ChainId.Polygon) {
            return forkPolygon(blockNumber);
        }
        if(chainId == ChainId.Fantom) {
            return forkFantom(blockNumber);
        }
        if(chainId == ChainId.Optimism) {
            return forkOptimism(blockNumber);
        }
        if(chainId == ChainId.Arbitrum) {
            return forkArbitrum(blockNumber);
        }
        if(chainId == ChainId.Avalanche) {
            return forkAvalanche(blockNumber);
        }
        if(chainId == ChainId.Moonriver) {
            return forkMoonriver(blockNumber);
        }

        revert(string.concat("fork: unknown chainId ", vm.toString(chainId)));
    }

    function forkMainnet(uint256 blockNumber) internal returns (uint256) {
        if (blockNumber == Block.Latest) {
            return vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));
        }
        return vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), blockNumber);
    }

    function forkOptimism(uint256 blockNumber) internal returns (uint256) {
        if (blockNumber == Block.Latest) {
            return vm.createSelectFork(vm.envString("OPTIMISM_RPC_URL"));
        }
        return vm.createSelectFork(vm.envString("OPTIMISM_RPC_URL"), blockNumber);
    }

    function forkFantom(uint256 blockNumber) internal returns (uint256) {
        if (blockNumber == Block.Latest) {
            return vm.createSelectFork(vm.envString("FANTOM_RPC_URL"));
        }
        return vm.createSelectFork(vm.envString("FANTOM_RPC_URL"), blockNumber);
    }

    function forkAvalanche(uint256 blockNumber) internal returns (uint256) {
        if (blockNumber == Block.Latest) {
            return vm.createSelectFork(vm.envString("AVALANCHE_RPC_URL"));
        }
        return vm.createSelectFork(vm.envString("AVALANCHE_RPC_URL"), blockNumber);
    }

    function forkArbitrum(uint256 blockNumber) internal returns (uint256) {
        if (blockNumber == Block.Latest) {
            return vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"));
        }
        return vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"), blockNumber);
    }

    function forkBSC(uint256 blockNumber) internal returns (uint256) {
        if (blockNumber == Block.Latest) {
            return vm.createSelectFork(vm.envString("BSC_RPC_URL"));
        }
        return vm.createSelectFork(vm.envString("BSC_RPC_URL"), blockNumber);
    }

    function forkPolygon(uint256 blockNumber) internal returns (uint256) {
        if (blockNumber == Block.Latest) {
            return vm.createSelectFork(vm.envString("POLYGON_RPC_URL"));
        }
        return vm.createSelectFork(vm.envString("POLYGON_RPC_URL"), blockNumber);
    }

    function forkMoonriver(uint256 blockNumber) internal returns (uint256) {
        if (blockNumber == Block.Latest) {
            return vm.createSelectFork(vm.envString("MOONRIVER_RPC_URL"));
        }
        return vm.createSelectFork(vm.envString("MOONRIVER_RPC_URL"), blockNumber);
    }
}
