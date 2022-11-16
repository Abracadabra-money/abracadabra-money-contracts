// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "utils/Constants.sol";

abstract contract BaseScript is Script {
    Constants internal immutable constants = new Constants(vm);
    bool internal testing;

    function deployer() public view returns (address) {
        return tx.origin;
    }

    function setTesting(bool _testing) public {
        testing = _testing;
    }

    function getChainIdKey() public view returns (ChainId) {
        return constants.getChainIdKey(block.chainid);
    }
}
