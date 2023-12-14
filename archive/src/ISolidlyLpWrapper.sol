// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "interfaces/IERC20Vault.sol";
import "interfaces/IVaultHarvester.sol";

interface ISolidlyLpWrapper is IERC20Vault {
    function harvest(uint256 minAmountOut) external returns (uint256 amountOut);

    function setStrategyExecutor(address executor, bool value) external;

    function setHarvester(IVaultHarvester _harvester) external;

    function setFeeParameters(address _feeCollector, uint8 _feePercent) external;

    function harvester() external view returns (IVaultHarvester);
}
