// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {Owned} from "solmate/auth/Owned.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {IFeeRateModel} from "/mimswap/interfaces/IFeeRateModel.sol";
import {IMagicLP} from "/mimswap/interfaces/IMagicLP.sol";
import {MagicLP} from "/mimswap/MagicLP.sol";
import {Registry} from "/mimswap/periphery/Registry.sol";

/// @notice Factory contract for MagicLP that registers created contracts in a Registry.
contract Factory is Owned {
    event LogCreated(
        address clone_,
        address indexed baseToken_,
        address indexed quoteToken_,
        address indexed creator_,
        uint256 lpFeeRate_,
        IFeeRateModel maintainerFeeRateModel,
        uint256 i_,
        uint256 k_
    );

    event LogSetImplementation(address indexed implementation);
    event LogSetMaintainer(address indexed newMaintainer);
    event LogSetMaintainerFeeRateModel(IFeeRateModel newMaintainerFeeRateModel);
    event LogSetRegistry(Registry registry);

    address public implementation;
    address public maintainer;
    IFeeRateModel public maintainerFeeRateModel;
    Registry public registry;

    constructor(
        address implementation_,
        address maintainer_,
        IFeeRateModel maintainerFeeRateModel_,
        Registry registry_,
        address owner_
    ) Owned(owner_) {
        implementation = implementation_;
        maintainer = maintainer_;
        maintainerFeeRateModel = maintainerFeeRateModel_;
        registry = registry_;
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// PUBLIC
    //////////////////////////////////////////////////////////////////////////////////////

    function predictDeterministicAddress(
        address baseToken_,
        address quoteToken_,
        uint256 lpFeeRate_,
        uint256 i_,
        uint256 k_
    ) public view returns (address) {
        return
            LibClone.predictDeterministicAddress(implementation, _computeSalt(baseToken_, quoteToken_, lpFeeRate_, i_, k_), address(this));
    }

    function create(address baseToken_, address quoteToken_, uint256 lpFeeRate_, uint256 i_, uint256 k_) external returns (address clone) {
        bytes32 salt = _computeSalt(baseToken_, quoteToken_, lpFeeRate_, i_, k_);
        clone = LibClone.cloneDeterministic(address(implementation), salt);
        IMagicLP(clone).init(maintainer, address(baseToken_), address(quoteToken_), lpFeeRate_, address(maintainerFeeRateModel), i_, k_);
        registry.register(clone, msg.sender);
        emit LogCreated(clone, baseToken_, quoteToken_, msg.sender, lpFeeRate_, maintainerFeeRateModel, i_, k_);
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// ADMIN
    //////////////////////////////////////////////////////////////////////////////////////

    function setLpImplementation(address implementation_) external onlyOwner {
        implementation = implementation_;
        emit LogSetImplementation(implementation_);
    }

    function setMaintainer(address maintainer_) external onlyOwner {
        maintainer = maintainer_;
        emit LogSetMaintainer(maintainer_);
    }

    function setMaintainerFeeRateModel(IFeeRateModel maintainerFeeRateModel_) external onlyOwner {
        maintainerFeeRateModel = maintainerFeeRateModel_;
        emit LogSetMaintainerFeeRateModel(maintainerFeeRateModel_);
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// INTERNALS
    //////////////////////////////////////////////////////////////////////////////////////

    function _computeSalt(
        address baseToken_,
        address quoteToken_,
        uint256 lpFeeRate_,
        uint256 i_,
        uint256 k_
    ) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(implementation, baseToken_, quoteToken_, lpFeeRate_, i_, k_));
    }
}
