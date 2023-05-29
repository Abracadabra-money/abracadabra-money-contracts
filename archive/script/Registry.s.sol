// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "periphery/Registry.sol";

contract RegistryScript is BaseScript {
    function deploy() public returns (Registry registry) {
        address safe;
        address devOps = constants.getAddress("safe.devOps");
        CauldronInfo[] memory cauldrons;

        startBroadcast();

        registry = new Registry();

        if (block.chainid == ChainId.Mainnet) {
            safe = constants.getAddress("mainnet.safe.ops");
            cauldrons = constants.getCauldrons("mainnet", true);
        } else if (block.chainid == ChainId.Arbitrum) {
            safe = constants.getAddress("arbitrum.safe.ops");
            cauldrons = constants.getCauldrons("arbitrum", true);

            if (!testing) {
                uint i = 0;
                bytes32[] memory keys = new bytes32[](2);
                bytes[] memory contents = new bytes[](2);

                keys[i] = keccak256(abi.encode("mim"));
                contents[i++] = abi.encode(constants.getAddress("arbitrum.mim"));

                keys[i] = keccak256(abi.encode("degenBox"));
                contents[i++] = abi.encode(constants.getAddress("arbitrum.degenBox"));

                registry.setMany(keys, contents, "(address)", "");
            }
        } else if (block.chainid == ChainId.Optimism) {
            safe = constants.getAddress("optimism.safe.ops");
            cauldrons = constants.getCauldrons("optimism", true);
        } else if (block.chainid == ChainId.Avalanche) {
            safe = constants.getAddress("avalanche.safe.ops");
            cauldrons = constants.getCauldrons("avalanche", true);
        } else if (block.chainid == ChainId.Fantom) {
            // TODO
        } else {
            revert("unsupported chainid");
        }

        if (!testing) {
            bytes32[] memory keys = new bytes32[](cauldrons.length);
            bytes[] memory contents = new bytes[](cauldrons.length);
            string memory cauldronInfoEncoding = "(address,uint8,bool,uint256)";

            for (uint256 i = 0; i < cauldrons.length; i++) {
                keys[i] = keccak256(abi.encode(string.concat("cauldrons.", cauldrons[i].name)));
                contents[i] = abi.encode(cauldrons[i].cauldron, cauldrons[i].version, cauldrons[i].deprecated, cauldrons[i].creationBlock);
            }

            registry.setMany(keys, contents, cauldronInfoEncoding, keccak256(abi.encode("cauldrons")));
            registry.setOperator(tx.origin, false);
            registry.setOperator(safe, true);
            registry.setOperator(devOps, true);
            registry.transferOwnership(safe, true, false);
        }

        stopBroadcast();
    }
}
