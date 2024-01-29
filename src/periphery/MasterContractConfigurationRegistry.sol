// SPDX-License-Identifier: MIT
pragma solidity >=0.8;

import {Owned} from "solmate/auth/Owned.sol";
import {ICauldronV1} from "interfaces/ICauldronV1.sol";

struct MasterContractConfiguration {
    uint24 collaterizationRate;
    uint24 liquidationMultiplier;
}

contract MasterContractConfigurationRegistry is Owned {
    error ErrInvalidConfigration();
    error ErrInvalidMasterContract(ICauldronV1 masterContract);
    error ErrLengthMismatch();

    mapping(ICauldronV1 => MasterContractConfiguration) public configurations;

    constructor(address owner_) Owned(owner_) {}

    function setConfigurations(
        ICauldronV1[] calldata masterContracts_,
        MasterContractConfiguration[] calldata configurations_
    ) external onlyOwner {
        if (masterContracts_.length != configurations_.length) {
            revert ErrLengthMismatch();
        }

        for (uint256 i = 0; i < masterContracts_.length; ++i) {
            ICauldronV1 masterContract = masterContracts_[i];
            MasterContractConfiguration calldata configuration = configurations_[i];

            if (address(masterContract) == address(0)) {
                revert ErrInvalidMasterContract(masterContract);
            }

            if (configuration.collaterizationRate == 0 || configuration.liquidationMultiplier == 0) {
                revert ErrInvalidConfigration();
            }

            configurations[masterContract] = configuration;
        }
    }

    function removeConfigurations(ICauldronV1[] calldata masterContracts_) external onlyOwner {
        for (uint256 i = 0; i < masterContracts_.length; ++i) {
            ICauldronV1 masterContract = masterContracts_[i];

            if (address(masterContract) == address(0)) {
                revert ErrInvalidMasterContract(masterContract);
            }

            delete configurations[masterContract];
        }
    }
}
