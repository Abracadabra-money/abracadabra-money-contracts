// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.0;

import {LockingMultiRewards} from "staking/LockingMultiRewards.sol";
import {BlastYields} from "/blast/libraries/BlastYields.sol";
import {BlastPoints} from "/blast/libraries/BlastPoints.sol";
import {BlastTokenRegistry} from "/blast/BlastTokenRegistry.sol";

contract BlastLockingMultiRewards is LockingMultiRewards {
    event LogFeeToChanged(address indexed feeTo);

    error ErrNotNativeYieldToken();
    error ErrZeroAddress();

    BlastTokenRegistry public immutable registry;
    address public feeTo;

    constructor(
        BlastTokenRegistry registry_,
        address feeTo_,
        address _stakingToken,
        uint256 _lockingBoostMultiplerInBips,
        uint256 _rewardsDuration,
        uint256 _lockDuration,
        address _owner
    ) LockingMultiRewards(_stakingToken, _lockingBoostMultiplerInBips, _rewardsDuration, _lockDuration, _owner) {
        if (address(registry_) == address(0)) {
            revert ErrZeroAddress();
        }
        if (feeTo_ == address(0)) {
            revert ErrZeroAddress();
        }

        registry = registry_;
        feeTo = feeTo_;

        BlastYields.configureDefaultClaimables(address(this));
        BlastPoints.configure();

        if (registry.nativeYieldTokens(_stakingToken)) {
            BlastYields.enableTokenClaimable(_stakingToken);
        }
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// OPERATORS
    //////////////////////////////////////////////////////////////////////////////////////

    function claimGasYields() external onlyOperators returns (uint256) {
        return BlastYields.claimMaxGasYields(feeTo);
    }

    function claimTokenYields(address token) external onlyOperators returns (uint256 amount) {
        if (token != stakingToken && !_rewardData[token].exists) {
            revert ErrInvalidTokenAddress();
        }

        if (!registry.nativeYieldTokens(token)) {
            revert ErrNotNativeYieldToken();
        }

        return BlastYields.claimAllTokenYields(token, feeTo);
    }

    function updateTokenClaimables(address token) external onlyOperators {
        if (registry.nativeYieldTokens(token)) {
            BlastYields.enableTokenClaimable(token);
        }
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// ADMIN
    //////////////////////////////////////////////////////////////////////////////////////

    function addReward(address rewardToken) public override onlyOwner {
        _addReward(rewardToken);

        if (registry.nativeYieldTokens(rewardToken)) {
            BlastYields.enableTokenClaimable(rewardToken);
        }
    }

    function callBlastPrecompile(bytes calldata data) external onlyOwner {
        BlastYields.callPrecompile(data);
    }

    function setFeeTo(address feeTo_) external onlyOwner {
        if (feeTo_ == address(0)) {
            revert ErrZeroAddress();
        }

        feeTo = feeTo_;
        emit LogFeeToChanged(feeTo_);
    }
}
