// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {OwnableOperators} from "/mixins/OwnableOperators.sol";

abstract contract BaseRewardDistributor is OwnableOperators {
    using SafeTransferLib for address;

    event LogRescue(address indexed token, address indexed to, uint256 amount);
    event LogRewardDistributionSet(address indexed staking, address indexed reward, uint256 amount);
    event LogVaultSet(address indexed previous, address indexed current);
    event LogDistributed(address indexed staking, address indexed reward, uint256 amount);

    error ErrNotReady();

    mapping(address staking => mapping(address token => uint256 amount)) public rewardDistributions;

    address public vault;

    constructor(address _vault, address _owner) {
        vault = _vault;
        _initializeOwner(_owner);
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////
    /// OPERATORS
    ////////////////////////////////////////////////////////////////////////////////////////////////

    function distribute(address _staking) external onlyOperators {
        if (!ready(_staking)) {
            revert ErrNotReady();
        }

        _onDistribute(_staking);
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////
    /// TO IMPLEMENT
    ////////////////////////////////////////////////////////////////////////////////////////////////

    function ready(address _staking) public view virtual returns (bool);

    function _onDistribute(address _staking) internal virtual;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    /// ADMIN
    ////////////////////////////////////////////////////////////////////////////////////////////////

    function setRewardDistribution(address _staking, address _token, uint256 _amount) external onlyOwner {
        rewardDistributions[_staking][_token] = _amount;

        if (_amount > 0) {
            _token.safeApprove(_staking, type(uint256).max);
        }

        emit LogRewardDistributionSet(_staking, _token, _amount);
    }

    function setVault(address _vault) external onlyOwner {
        emit LogVaultSet(vault, _vault);
        vault = _vault;
    }

    function setAllowance(address _token, address _spender, uint256 _amount) external onlyOwner {
        _token.safeApprove(_spender, _amount);
    }

    function rescue(address _token, address _to, uint256 _amount) external onlyOwner {
        _token.safeTransfer(_to, _amount);
        emit LogRescue(_token, _to, _amount);
    }
}
