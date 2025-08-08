// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Owned} from "@solmate/auth/Owned.sol";
import {GlpOracle} from "/oracles/GlpOracle.sol";
import {IOracle} from "/interfaces/IOracle.sol";
import {MagicGlpV2Oracle} from "/oracles/MagicGlpV2Oracle.sol";
import {BaseScript, ChainId} from "utils/BaseScript.sol";

contract MagicGlpV2OracleScript is BaseScript {
    function deploy() public returns (MagicGlpV2Oracle magicGlpV2Oracle, GlpOracle glpOracle) {
        require(block.chainid == ChainId.Arbitrum, "Wrong chain");

        address safe = toolkit.getAddress("safe.ops");
        address magicGlp = toolkit.getAddress("magicGlp");
        address glpManager = toolkit.getAddress("gmx.glpManager");
        address glp = toolkit.getAddress("gmx.glp");
        address sGlp = toolkit.getAddress("gmx.sGLP");
        address gmEth = toolkit.getAddress("gmx.v2.gmETH");
        IOracle gmEthOracle = IOracle(toolkit.getAddress("oracle.gmETH"));

        vm.startBroadcast();

        glpOracle = GlpOracle(deploy("GlpOracle", "GlpOracle.sol:GlpOracle", abi.encode(glpManager, glp)));
        magicGlpV2Oracle = MagicGlpV2Oracle(deploy("MagicGlpV2Oracle", "MagicGlpV2Oracle.sol:MagicGlpV2Oracle", abi.encode("USD/MagicGLP", "USD/MagicGlp", magicGlp)));

        magicGlpV2Oracle.setOracle(sGlp, glpOracle);
        magicGlpV2Oracle.setOracle(gmEth, gmEthOracle);

        if (!testing()) {
            if (magicGlpV2Oracle.owner() != safe) {
                magicGlpV2Oracle.transferOwnership(safe);
            }
        }

        vm.stopBroadcast();
    }
}
