// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {IBlastBox} from "/blast/interfaces/IBlastBox.sol";
import {FeeCollectable} from "mixins/FeeCollectable.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {ProxyOracle} from "oracles/ProxyOracle.sol";
import {FixedPriceOracle} from "oracles/FixedPriceOracle.sol";
import {ICauldronV4} from "interfaces/ICauldronV4.sol";
import {CauldronDeployLib} from "utils/CauldronDeployLib.sol";
import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {IOracle} from "interfaces/IOracle.sol";
import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {BlastTokenRegistry} from "/blast/BlastTokenRegistry.sol";

contract BlastScript is BaseScript {
    function deploy() public returns (address blastBox) {
        address feeTo = toolkit.getAddress(ChainId.Blast, "safe.ops");
        address safe = feeTo;

        (address blastGovernor, address blastTokenRegistry) = deployPrerequisites(tx.origin, feeTo);

        vm.startBroadcast();

        blastBox = deploy(
            "BlastBox",
            "BlastBox.sol:BlastBox",
            abi.encode(toolkit.getAddress(ChainId.Blast, "weth"), blastTokenRegistry, feeTo)
        );

        address mim = deploy(
            "MIM",
            "MintableBurnableERC20.sol:MintableBurnableERC20",
            abi.encode(tx.origin, "Magic Internet Money", "MIM", 18)
        );

        deploy("CauldronV4", "BlastWrappers.sol:BlastCauldronV4", abi.encode(blastBox, mim, blastGovernor));
        ProxyOracle oracle = ProxyOracle(deploy("MIMUSDB_Oracle", "ProxyOracle.sol:ProxyOracle", ""));
        FixedPriceOracle fixedPriceOracle = FixedPriceOracle(
            deploy("MIMUSDB_Oracle_Impl", "FixedPriceOracle.sol:FixedPriceOracle", abi.encode("MIM/USDB", 1e18, 18))
        );

        if (oracle.oracleImplementation() != IOracle(address(fixedPriceOracle))) {
            oracle.changeOracleImplementation(fixedPriceOracle);
        }

        /* ICauldronV4 cauldron = CauldronDeployLib.deployCauldronV4(
            "CauldronV4_MimUsdbLP",
            IBentoBoxV1(toolkit.getAddress(ChainId.Blast, "degenBox")),
            toolkit.getAddress(ChainId.Blast, "cauldronV4"),
            IERC20(toolkit.getAddress(ChainId.Blast, "TODO")),
            IOracle(address(0x3de60fF9031F9C8E5D361e4D1611042A050E4198)),
            "",
            9000, // 90% ltv
            500, // 5% interests
            100, // 1% opening
            600 // 6% liquidation
        );*/

        if (!testing()) {
            address weth = toolkit.getAddress(ChainId.Blast, "weth");
            address usdb = toolkit.getAddress(ChainId.Blast, "usdb");

            if (!IBlastBox(blastBox).enabledTokens(weth)) {
                IBlastBox(blastBox).setTokenEnabled(weth, true);
            }
            if (!IBlastBox(blastBox).enabledTokens(usdb)) {
                IBlastBox(blastBox).setTokenEnabled(usdb, true);
            }
            if (IBlastBox(blastBox).feeTo() != feeTo) {
                IBlastBox(blastBox).setFeeTo(feeTo);
            }
            if (Owned(mim).owner() != safe) {
                Owned(mim).transferOwnership(safe);
            }
        }
        vm.stopBroadcast();
    }

    function deployPrerequisites(address owner, address feeTo) public returns (address blastGovernor, address blastTokenRegistry) {
        vm.startBroadcast();
        blastGovernor = deploy("BlastGovernor", "BlastGovernor.sol:BlastGovernor", abi.encode(feeTo, tx.origin));
        blastTokenRegistry = deploy("BlastTokenRegistry", "BlastTokenRegistry.sol:BlastTokenRegistry", abi.encode(tx.origin));

        if (!testing()) {
            address weth = toolkit.getAddress(ChainId.Blast, "weth");
            address usdb = toolkit.getAddress(ChainId.Blast, "usdb");

            if (!BlastTokenRegistry(blastTokenRegistry).nativeYieldTokens(weth)) {
                BlastTokenRegistry(blastTokenRegistry).registerNativeYieldToken(weth);
            }
            if (!BlastTokenRegistry(blastTokenRegistry).nativeYieldTokens(usdb)) {
                BlastTokenRegistry(blastTokenRegistry).registerNativeYieldToken(usdb);
            }
            if (BlastTokenRegistry(blastTokenRegistry).owner() != owner) {
                BlastTokenRegistry(blastTokenRegistry).transferOwnership(owner);
            }
        }
        vm.stopBroadcast();
    }
}
