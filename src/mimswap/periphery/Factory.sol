// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {Owned} from "solmate/auth/Owned.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {IFeeRateModel} from "/mimswap/interfaces/IFeeRateModel.sol";
import {IMagicLP} from "/mimswap/interfaces/IMagicLP.sol";
import {MagicLP} from "/mimswap/MagicLP.sol";
import "forge-std/console2.sol";

/// @notice Create and register MagicLP pools
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

    event LogPoolAdded(address baseToken, address quoteToken, address creator, address pool);
    event LogPoolRemoved(address pool);
    event LogSetImplementation(address indexed implementation);
    event LogSetMaintainer(address indexed newMaintainer);
    event LogSetMaintainerFeeRateModel(IFeeRateModel newMaintainerFeeRateModel);

    error ErrInvalidUserPoolIndex();
    error ErrZeroAddress();
    
    address public implementation;
    IFeeRateModel public maintainerFeeRateModel;

    mapping(address base => mapping(address quote => address[] pools)) public pools;
    mapping(address creator => address[] pools) public userPools;

    constructor(address implementation_, IFeeRateModel maintainerFeeRateModel_, address owner_) Owned(owner_) {
        if (implementation_ == address(0)) {
            revert ErrZeroAddress();
        }
        if (address(maintainerFeeRateModel_) == address(0)) {
            revert ErrZeroAddress();
        }
        implementation = implementation_;
        maintainerFeeRateModel = maintainerFeeRateModel_;
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// VIEWS
    //////////////////////////////////////////////////////////////////////////////////////

    function getPoolCount(address token0, address token1) external view returns (uint256) {
        return pools[token0][token1].length;
    }

    function getUserPoolCount(address creator) external view returns (uint256) {
        return userPools[creator].length;
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
        IMagicLP(clone).init(address(baseToken_), address(quoteToken_), lpFeeRate_, address(maintainerFeeRateModel), i_, k_);

        emit LogCreated(clone, baseToken_, quoteToken_, msg.sender, lpFeeRate_, maintainerFeeRateModel, i_, k_);
        _addPool(msg.sender, baseToken_, quoteToken_, clone);
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// ADMIN
    //////////////////////////////////////////////////////////////////////////////////////

    function setLpImplementation(address implementation_) external onlyOwner {
        if (implementation_ == address(0)) {
            revert ErrZeroAddress();
        }

        implementation = implementation_;
        emit LogSetImplementation(implementation_);
    }

    function setMaintainerFeeRateModel(IFeeRateModel maintainerFeeRateModel_) external onlyOwner {
        if (address(maintainerFeeRateModel_) == address(0)) {
            revert ErrZeroAddress();
        }

        maintainerFeeRateModel = maintainerFeeRateModel_;
        emit LogSetMaintainerFeeRateModel(maintainerFeeRateModel_);
    }

    /// @notice Register a pool to the list
    /// Note this doesn't check if the pool is valid or if it's already registered.
    function addPool(address creator, address baseToken, address quoteToken, address pool) external onlyOwner {
        _addPool(creator, baseToken, quoteToken, pool);
    }

    function removePool(
        address creator,
        address baseToken,
        address quoteToken,
        uint256 poolIndex,
        uint256 userPoolIndex
    ) external onlyOwner {
        address[] storage _pools = pools[baseToken][quoteToken];
        address pool = _pools[poolIndex];
        address[] storage _userPools = userPools[creator];

        _pools[poolIndex] = _pools[_pools.length - 1];
        _pools.pop();

        if (_userPools[userPoolIndex] != pool) {
            revert ErrInvalidUserPoolIndex();
        }

        _userPools[userPoolIndex] = _userPools[_userPools.length - 1];
        _userPools.pop();

        emit LogPoolRemoved(pool);
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// INTERNALS
    //////////////////////////////////////////////////////////////////////////////////////

    function _addPool(address creator, address baseToken, address quoteToken, address pool) internal {
        pools[baseToken][quoteToken].push(pool);
        userPools[creator].push(pool);

        emit LogPoolAdded(baseToken, quoteToken, creator, pool);
    }

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
