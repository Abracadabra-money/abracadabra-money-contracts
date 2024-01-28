// SPDX-License-Identifier: MIT
pragma solidity >=0.8;

import {ICauldronV1} from "interfaces/ICauldronV1.sol";
import {ICauldronV2} from "interfaces/ICauldronV2.sol";
import {CauldronRegistry} from "periphery/CauldronRegistry.sol";
import {MasterContractConfigurationRegistry} from "periphery/MasterContractConfigurationRegistry.sol";
import {Owned} from "solmate/auth/Owned.sol";

interface IOracleUpdater {
    function updateCauldrons(ICauldronV1[] memory cauldrons_) external;
}

interface IGelatoChecker {
    function checker() external view returns (bool canExec, bytes memory execPayload);
}

contract OracleUpdater is IOracleUpdater, IGelatoChecker {
    uint256 private constant EXCHANGERATE_PRECISION = 1e18;
    uint256 private constant COLLATERIZATION_RATE_PRECISION = 1e5;
    uint256 private constant LIQUIDATION_MULTIPLIER_PRECISION = 1e5;

    CauldronRegistry cauldronRegistry;
    MasterContractConfigurationRegistry masterContractConfigurationRegistry;

    constructor(CauldronRegistry cauldronRegistry_, MasterContractConfigurationRegistry masterContractConfigurationRegistry_) {
        cauldronRegistry = cauldronRegistry_;
        masterContractConfigurationRegistry = masterContractConfigurationRegistry_;
    }

    function updateCauldrons(ICauldronV1[] calldata cauldrons_) external override {
        for (uint256 i = 0; i < cauldrons_.length; ++i) {
            cauldrons_[i].updateExchangeRate();
        }
    }

    function checker() external view override returns (bool canExec, bytes memory execPayload) {
        canExec = false;
        uint256 len;
        uint256 cauldronsLength = cauldronRegistry.cauldronsLength();
        bool[] memory isToBeUpdated = new bool[](cauldronsLength);

        for (uint256 i = 0; i < cauldronsLength; ++i) {
            ICauldronV1 cauldron = cauldronRegistry.cauldrons(i);

            (uint256 collaterizationRate, uint256 liquidationMultiplier) = masterContractConfigurationRegistry.configurations(
                cauldron.masterContract()
            );
            if (collaterizationRate == 0) {
                // Not registered --- assume V2 plus
                collaterizationRate = ICauldronV2(address(cauldron)).COLLATERIZATION_RATE();
                liquidationMultiplier = ICauldronV2(address(cauldron)).LIQUIDATION_MULTIPLIER();
            }
            uint256 collateralizationDelta = COLLATERIZATION_RATE_PRECISION - collaterizationRate;
            uint256 liquidationDelta = liquidationMultiplier - LIQUIDATION_MULTIPLIER_PRECISION;

            (, uint256 currentRate) = cauldron.oracle().peek(cauldron.oracleData());

            uint256 staleRate = cauldron.exchangeRate();

            // Effectively staleRate * (1 - LTV)
            uint256 collaterizationBuffer = (staleRate * collateralizationDelta) / COLLATERIZATION_RATE_PRECISION;
            // Effectively staleRate * (liquidationMultiplier - 1)
            uint256 liquidationBuffer = (staleRate * liquidationDelta) / LIQUIDATION_MULTIPLIER_PRECISION;
            if (staleRate + collaterizationBuffer - liquidationBuffer < currentRate) {
                canExec = true;
                isToBeUpdated[i] = true;
                unchecked {
                    len++;
                }
            }
        }

        ICauldronV1[] memory toBeUpdated = new ICauldronV1[](len);

        for (uint256 i = 0; i < cauldronsLength; ++i) {
            if (isToBeUpdated[i]) {
                toBeUpdated[toBeUpdated.length - len] = cauldronRegistry.cauldrons(i);
                unchecked {
                    --len;
                }
            }
        }

        execPayload = abi.encodeCall(IOracleUpdater.updateCauldrons, (toBeUpdated));
    }
}
