// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ICauldronV2} from "interfaces/ICauldronV2.sol";

interface IOracleUpdater {
    function updateCauldrons(ICauldronV2[] memory cauldrons_) external;
}

interface IGelatoChecker {
    function checker() external view returns (bool canExec, bytes memory execPayload);
}

struct MasterContract {
    ICauldronV2 masterContractAddress;
    uint24 collaterizationRate;
    uint24 liquidationMultiplier;
}

struct MasterContractParameters {
    uint24 collaterizationRate;
    uint24 liquidationMultiplier;
}

contract OracleUpdater is IOracleUpdater, IGelatoChecker {
    uint256 private constant EXCHANGERATE_PRECISION = 1e18;
    uint256 private constant COLLATERIZATION_RATE_PRECISION = 1e5;
    uint256 private constant LIQUIDATION_MULTIPLIER_PRECISION = 1e5;

    mapping(ICauldronV2 => MasterContractParameters) public masterContractOverridesParameters;

    ICauldronV2[] public cauldrons;

    constructor(ICauldronV2[] memory cauldrons_, MasterContract[] memory masterContractOverrides_) {
        cauldrons = cauldrons_;
        for (uint256 i = 0; i < masterContractOverrides_.length; ++i) {
            MasterContract memory masterContract = masterContractOverrides_[i];
            masterContractOverridesParameters[masterContract.masterContractAddress] = MasterContractParameters(
                masterContract.collaterizationRate,
                masterContract.liquidationMultiplier
            );
        }
    }

    function updateCauldrons(ICauldronV2[] calldata cauldrons_) external override {
        for (uint256 i = 0; i < cauldrons_.length; ++i) {
            cauldrons_[i].updateExchangeRate();
        }
    }

    function checker() external view override returns (bool canExec, bytes memory execPayload) {
        canExec = false;
        uint256 len;
        bool[] memory isToBeUpdated = new bool[](cauldrons.length);

        for (uint256 i = 0; i < cauldrons.length; ++i) {
            ICauldronV2 cauldron = cauldrons[i];
            ICauldronV2 masterContract = cauldron.masterContract();

            MasterContractParameters memory masterContractParameters = masterContractOverridesParameters[masterContract];
            if (masterContractParameters.collaterizationRate == 0) {
                masterContractParameters = MasterContractParameters(
                    uint24(cauldron.COLLATERIZATION_RATE()),
                    uint24(cauldron.LIQUIDATION_MULTIPLIER())
                );
            }
            uint256 collateralizationDelta = COLLATERIZATION_RATE_PRECISION - masterContractParameters.collaterizationRate;
            uint256 liquidationDelta = masterContractParameters.liquidationMultiplier - LIQUIDATION_MULTIPLIER_PRECISION;

            (, uint256 currentRate) = cauldron.oracle().peek(cauldron.oracleData());

            uint256 staleRate = cauldron.exchangeRate();

            // Effectively staleRate * (1 - LTV)
            uint256 collaterizationBuffer = (staleRate * collateralizationDelta) / COLLATERIZATION_RATE_PRECISION;
            // Effectively staleRate * (liquidationMultiplier - 1)
            uint256 liquidationBuffer = (staleRate * liquidationDelta) / LIQUIDATION_MULTIPLIER_PRECISION;
            if (staleRate + collaterizationBuffer - liquidationBuffer < currentRate) {
                canExec = true;
                isToBeUpdated[i] = true;
                len++;
            }
        }

        ICauldronV2[] memory toBeUpdated = new ICauldronV2[](len);

        for (uint256 i = 0; i < cauldrons.length; ++i) {
            if (isToBeUpdated[i]) {
                toBeUpdated[toBeUpdated.length - len] = cauldrons[i];
                --len;
            }
        }

        execPayload = abi.encodeCall(IOracleUpdater.updateCauldrons, (toBeUpdated));
    }
}
