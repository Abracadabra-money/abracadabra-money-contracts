// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./Common.sol";

contract BaseTest is Test, Common {
    bytes32 internal constant nextUser = keccak256(abi.encodePacked("user address"));

    address payable internal deployer;
    address payable internal immutable alice;
    address payable internal immutable bob;
    address payable internal immutable carol;

    constructor() {
        alice = createUser("alice");
        bob = createUser("bob");
        carol = createUser("carol");
    }

    function setUp() public virtual {
        deployer = payable(address(msg.sender));
        vm.deal(deployer, 100 ether);
        vm.label(deployer, "deployer");
    }

    function createUser(string memory label) internal returns (address payable) {
        address payable user = payable(address(uint160(uint256(nextUser))));
        vm.deal(user, 100 ether);
        vm.label(user, label);
        return user;
    }

    // move block.number forward by a given number of blocks
    function mineBlocks(uint256 numBlocks) external {
        uint256 targetBlock = block.number + numBlocks;
        vm.roll(targetBlock);
    }
}
