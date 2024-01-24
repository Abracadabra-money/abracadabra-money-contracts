// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import {MasterContract, OracleUpdater} from "periphery/OracleUpdater.sol";
import {ICauldronV2} from "interfaces/ICauldronV2.sol";
import {IOracle} from "interfaces/IOracle.sol";

contract OracleUpdaterTest is Test {
    function mockCauldron(
        ICauldronV2 cauldron,
        ICauldronV2 masterContract,
        uint24 collaterizationRate,
        uint24 liquidationMultiplier,
        uint256 exchangeRate,
        IOracle oracle,
        uint256 oracleExchangeRate
    ) internal {
        vm.mockCall(address(cauldron), abi.encodeWithSelector(ICauldronV2.masterContract.selector), abi.encode(masterContract));
        vm.mockCall(address(cauldron), abi.encodeWithSelector(ICauldronV2.COLLATERIZATION_RATE.selector), abi.encode(collaterizationRate));
        vm.mockCall(
            address(cauldron),
            abi.encodeWithSelector(ICauldronV2.LIQUIDATION_MULTIPLIER.selector),
            abi.encode(liquidationMultiplier)
        );
        vm.mockCall(address(cauldron), abi.encodeWithSelector(ICauldronV2.exchangeRate.selector), abi.encode(exchangeRate));
        vm.mockCall(address(cauldron), abi.encodeWithSelector(ICauldronV2.oracleData.selector), abi.encode(0));
        vm.mockCall(address(cauldron), abi.encodeWithSelector(ICauldronV2.oracle.selector), abi.encode(oracle));
        vm.mockCall(address(oracle), abi.encodeWithSelector(IOracle.peek.selector), abi.encode(true, oracleExchangeRate));
        vm.mockCall(
            address(cauldron),
            abi.encodeWithSelector(ICauldronV2.updateExchangeRate.selector),
            abi.encode(exchangeRate != oracleExchangeRate, oracleExchangeRate)
        );
    }

    function testNonOverrideMasterContract() public {
        ICauldronV2 cauldron = ICauldronV2(makeAddr("Cauldron"));
        IOracle oracle = IOracle(makeAddr("Oracle"));
        uint24 collaterizationRate = 75000;
        uint24 liquidationMultiplier = 103000;
        mockCauldron(cauldron, ICauldronV2(makeAddr("MasterContract")), collaterizationRate, liquidationMultiplier, 10000, oracle, 100000);

        ICauldronV2[] memory cauldrons = new ICauldronV2[](1);
        cauldrons[0] = cauldron;
        OracleUpdater oracleUpdater = new OracleUpdater(cauldrons, new MasterContract[](0));

        vm.expectCall(address(cauldron), abi.encodeWithSelector(ICauldronV2.COLLATERIZATION_RATE.selector), 1);
        vm.expectCall(address(cauldron), abi.encodeWithSelector(ICauldronV2.LIQUIDATION_MULTIPLIER.selector), 1);

        (, bytes memory payload) = oracleUpdater.checker();
        (bool success, ) = address(oracleUpdater).call(payload);
        assertTrue(success);
    }

    function testOverrideMasterContract() public {
        ICauldronV2 cauldron = ICauldronV2(makeAddr("Cauldron"));
        IOracle oracle = IOracle(makeAddr("Oracle"));
        uint24 collaterizationRate = 75000;
        uint24 liquidationMultiplier = 103000;
        MasterContract memory masterContract = MasterContract(
            ICauldronV2(makeAddr("MasterContract")),
            collaterizationRate,
            liquidationMultiplier
        );
        mockCauldron(cauldron, masterContract.masterContractAddress, collaterizationRate, liquidationMultiplier, 10000, oracle, 100000);

        ICauldronV2[] memory cauldrons = new ICauldronV2[](1);
        cauldrons[0] = cauldron;

        MasterContract[] memory masterContractOverrides = new MasterContract[](1);
        masterContractOverrides[0] = masterContract;

        OracleUpdater oracleUpdater = new OracleUpdater(cauldrons, masterContractOverrides);

        vm.expectCall(address(cauldron), abi.encodeWithSelector(ICauldronV2.COLLATERIZATION_RATE.selector), 0);
        vm.expectCall(address(cauldron), abi.encodeWithSelector(ICauldronV2.LIQUIDATION_MULTIPLIER.selector), 0);

        (, bytes memory payload) = oracleUpdater.checker();
        (bool success, ) = address(oracleUpdater).call(payload);
        assertTrue(success);
    }
}
