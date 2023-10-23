// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Vm, VmSafe} from "forge-std/Vm.sol";
import {Deployer} from "forge-deploy/Deployer.sol";
import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {CauldronLib} from "libraries/CauldronLib.sol";
import {ICauldronV3} from "interfaces/ICauldronV3.sol";
import {ICauldronV4} from "interfaces/ICauldronV4.sol";
import {IOracle} from "interfaces/IOracle.sol";
import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
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

        (VmSafe.CallerMode callerMode, , ) = vm.readCallers();
        require(callerMode != VmSafe.CallerMode.Broadcast, "deployCauldronV4: unexpected broadcast mode");
        if (callerMode == VmSafe.CallerMode.RecurrentBroadcast) {
            vm.stopBroadcast();
        }
        deployer.save(deploymentName, address(cauldron), "CauldronV4.sol:CauldronV4");
        if (callerMode == VmSafe.CallerMode.RecurrentBroadcast) {
            vm.startBroadcast();
        }
    }
}
