// SPDX-License-Identifier: MIT
// solhint-disable avoid-low-level-calls
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import "libraries/SafeApprove.sol";
import "interfaces/IBentoBoxV1.sol";
import "swappers/CurveLevSwapper.sol";
import "interfaces/IERC4626.sol";
import "interfaces/ICurvePool.sol";

contract MagicCurveLpLevSwapper is CurveLevSwapper {
    using BoringERC20 for IERC20;
    using SafeApprove for IERC20;

    IERC4626 public immutable vault;

    constructor(
        IBentoBoxV1 _bentoBox,
        IERC4626 _vault,
        address _mim,
        CurvePoolInterfaceType _curvePoolInterfaceType,
        address _curvePool,
        address _curvePoolDepositor /* Optional Curve Deposit Zapper */,
        address[] memory _poolTokens,
        address _exchange
    )
        CurveLevSwapper(
            _bentoBox,
            address(_vault.asset()),
            _mim,
            _curvePoolInterfaceType,
            _curvePool,
            _curvePoolDepositor,
            _poolTokens,
            _exchange
        )
    {
        vault = _vault;
        IERC20(curveToken).safeApprove(address(_vault), type(uint256).max);
    }

    function depositInBentoBox(uint256 amount, address recipient) internal override returns (uint256 shareReturned) {
        // CurveLP -> MagicCurveLP
        amount = vault.deposit(amount, address(bentoBox));

        (, shareReturned) = bentoBox.deposit(IERC20(address(vault)), address(bentoBox), recipient, amount, 0);
    }
}
