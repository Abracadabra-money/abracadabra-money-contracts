// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
import "interfaces/IApeCoinStaking.sol";
import "interfaces/IERC4626.sol";

interface IMagicApe is IERC4626 {
    function staking() external view returns (IApeCoinStaking);

    function feePercentBips() external view returns (uint16);

    function feeCollector() external view returns (address);

    function setFeeParameters(address _feeCollector, uint16 _feePercentBips) external;

    function totalAssets() external view returns (uint256);

    function harvest() external;
}
