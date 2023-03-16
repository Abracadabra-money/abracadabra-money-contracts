// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "oracles/ProxyOracle.sol";
import "utils/BaseScript.sol";
import "utils/CauldronDeployLib.sol";
import "periphery/CauldronOwner.sol";

contract CauldronV4Script is BaseScript {
    function run() public {
        IBentoBoxV1 degenBox;
        address safe;
        ERC20 mim;

        if (block.chainid == ChainId.Mainnet) {
            degenBox = IBentoBoxV1(constants.getAddress("mainnet.degenBox"));
            safe = constants.getAddress("mainnet.safe.ops");
            mim = ERC20(constants.getAddress("mainnet.mim"));
        } else if (block.chainid == ChainId.Avalanche) {
            degenBox = IBentoBoxV1(constants.getAddress("avalanche.degenBox"));
            safe = constants.getAddress("avalanche.safe.ops");
            mim = ERC20(constants.getAddress("avalanche.mim"));
        }
        startBroadcast();

        CauldronOwner owner = new CauldronOwner(safe, mim);
        CauldronV4 cauldronV4MC = new CauldronV4(degenBox, mim);

        if (!testing) {
            owner.setOperator(safe, true);
            owner.transferOwnership(safe, true, false);
            cauldronV4MC.setFeeTo(safe);
            cauldronV4MC.transferOwnership(address(safe), true, false);
        }

        stopBroadcast();
    }
}
