// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@BoringSolidity/interfaces/IERC20.sol";
import {Vm, VmSafe} from "forge-std/Vm.sol";
import {console2} from "forge-std/console2.sol";
import {Deployer} from "./Deployment.sol";
import {CauldronLib} from "../src/libraries/CauldronLib.sol";
import {ICauldronV3} from "../src/interfaces/ICauldronV3.sol";
import {ICauldronV4} from "../src/interfaces/ICauldronV4.sol";
import {IOracle} from "../src/interfaces/IOracle.sol";
import {IBentoBoxV1} from "../src/interfaces/IBentoBoxV1.sol";
import {Toolkit} from "utils/Toolkit.sol";

library CauldronDeployLib {
    Vm constant vm = Vm(address(bytes20(uint160(uint256(keccak256("hevm cheat code"))))));
    Toolkit constant toolkit = Toolkit(address(bytes20(uint160(uint256(keccak256("toolkit"))))));

    /// Cauldron percentages parameters are in bips unit
    /// Examples:
    ///  1 = 0.01%
    ///  10_000 = 100%
    ///  250 = 2.5%
    ///
    /// Adapted from original calculation. (variables are % values instead of bips):
    ///  ltv = ltv * 1e3;
    ///  borrowFee = borrowFee * (1e5 / 100);
    ///  interest = interest * (1e18 / (365.25 * 3600 * 24) / 100);
    ///  liquidationFee = liquidationFee * 1e3 + 1e5;
    function getCauldronParameters(
        IERC20 collateral,
        IOracle oracle,
        bytes memory oracleData,
        uint256 ltvBips,
        uint256 interestBips,
        uint256 borrowFeeBips,
        uint256 liquidationFeeBips
    ) internal pure returns (bytes memory) {
        return
            abi.encode(
                collateral,
                oracle,
                oracleData,
                CauldronLib.getInterestPerSecond(interestBips),
                liquidationFeeBips * 1e1 + 1e5,
                ltvBips * 1e1,
                borrowFeeBips * 1e1
            );
    }

    function deployCauldronV4(
        string memory deploymentName,
        IBentoBoxV1 degenBox,
        address masterContract,
        IERC20 collateral,
        IOracle oracle,
        bytes memory oracleData,
        uint256 ltvBips,
        uint256 interestBips,
        uint256 borrowFeeBips,
        uint256 liquidationFeeBips
    ) internal returns (ICauldronV4 cauldron) {
        Deployer deployer = toolkit.deployer();
        deploymentName = toolkit.prefixWithChainName(block.chainid, deploymentName);

        if (toolkit.testing()) {
            deployer.ignoreDeployment(deploymentName);
        }

        if (deployer.has(deploymentName)) {
            return ICauldronV4(deployer.getAddress(deploymentName));
        }

        bytes memory data = getCauldronParameters(collateral, oracle, oracleData, ltvBips, interestBips, borrowFeeBips, liquidationFeeBips);
        cauldron = ICauldronV4(IBentoBoxV1(degenBox).deploy(masterContract, data, true));

        _saveCauldronDeployment(deployer, deploymentName, cauldron);
    }

    function _saveCauldronDeployment(Deployer deployer, string memory deploymentName, ICauldronV4 cauldron) private {
        if (!toolkit.testing()) {
            (VmSafe.CallerMode callerMode, , ) = vm.readCallers();
            require(callerMode != VmSafe.CallerMode.Broadcast, "deployCauldronV4: unexpected broadcast mode");
            if (callerMode == VmSafe.CallerMode.RecurrentBroadcast) {
                vm.stopBroadcast();
            }
            deployer.save(deploymentName, address(cauldron), "", "", "");
            if (callerMode == VmSafe.CallerMode.RecurrentBroadcast) {
                vm.startBroadcast();
            }

            (string memory path, ) = toolkit.getConfigFileInfo(block.chainid);

            console2.log("=========================================");
            console2.log("Cauldron deployed:", deploymentName, " at ", address(cauldron));
            console2.log("Add the cauldron entry to:");
            console2.log("  1. JSON config file: ", path);
            console2.log("  2. CauldronRegistry: ", toolkit.getAddress("cauldronRegistry"));
            console2.log("=========================================");
        } else {
            toolkit.setLabel(address(cauldron), deploymentName);
        }
    }
}
