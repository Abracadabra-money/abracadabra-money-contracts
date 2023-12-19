// SPDX-License-Identifier: MIT
// solhint-disable avoid-low-level-calls
pragma solidity >=0.8.0;

import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {BoringERC20} from "BoringSolidity/libraries/BoringERC20.sol";
import {CurveSwapper} from "swappers/CurveSwapper.sol";
import {SafeApproveLib} from "libraries/SafeApproveLib.sol";
import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {IERC4626} from "interfaces/IERC4626.sol";
import {ICurvePool, CurvePoolInterfaceType} from "interfaces/ICurvePool.sol";

contract MagicCurveLpSwapper is CurveSwapper {
    using BoringERC20 for IERC20;
    using SafeApproveLib for IERC20;

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
        CurveSwapper(
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
        if (_curvePoolDepositor != address(0)) {
            IERC20 curveToken = _vault.asset();
            curveToken.safeApprove(_curvePoolDepositor, type(uint256).max);
        }
    }

    function withdrawFromBentoBox(uint256 shareFrom) internal override returns (uint256 amount) {
        (amount, ) = bentoBox.withdraw(IERC20(address(vault)), address(this), address(this), 0, shareFrom);

        // MagicCurveLP -> CurveLP
        amount = vault.redeem(amount, address(this), address(this));
    }
}
