// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {PermissionedSwapper} from "/swappers/PermissionedSwapper.sol";

interface Sdeusd {
    function asset() external view returns (address);

    function unstake(address receiver) external;

    function cooldownShares(uint256 shares) external returns (uint256 assets);
}

contract SdeusdPermissionedSwapper is PermissionedSwapper {
    Sdeusd public immutable sdeusd;

    constructor(address owner_, Sdeusd sdeusd_) PermissionedSwapper(owner_, sdeusd_.asset()) {
        sdeusd = sdeusd_;
    }

    function _redeem(uint256 amountIn) internal virtual override returns (uint256 amountOut) {
        amountOut = sdeusd.cooldownShares(amountIn);
        sdeusd.unstake(address(this));
    }
}
