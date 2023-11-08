// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import "oracles/XF33dOracle.sol";

contract XF33dOracleScript is BaseScript {
    using DeployerFunctions for Deployer;

    bytes32 constant XF33D_ORACLE_SALT = keccak256(bytes("XF33dOracle-1693245497"));

    function deploy() public {
        vm.startBroadcast();
        XF33dOracle oracle = XF33dOracle(
            deployUsingCreate3(
                toolkit.prefixWithChainName(block.chainid, "XF33dOracle"),
                XF33D_ORACLE_SALT,
                "XF33dOracle.sol:XF33dOracle",
                abi.encode(toolkit.getAddress(block.chainid, "LZendpoint"), tx.origin),
                0
            )
        );

        bytes memory remoteAndLocal = abi.encodePacked(address(oracle), address(oracle));
        if (block.chainid == ChainId.Kava) {
            oracle.setTrustedRemote(LayerZeroChainId.Arbitrum, remoteAndLocal);
        } else if (block.chainid == ChainId.Arbitrum) {
            oracle.setTrustedRemote(LayerZeroChainId.Kava, remoteAndLocal);
        } else {
            revert("Unsupported chain");
        }
        vm.stopBroadcast();
    }
}
