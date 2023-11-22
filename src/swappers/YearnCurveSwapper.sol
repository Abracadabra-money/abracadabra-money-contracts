// SPDX-License-Identifier: MIT
// solhint-disable avoid-low-level-calls
pragma solidity >=0.8.0;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {CurveSwapper} from "swappers/CurveSwapper.sol";
import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {IYearnVault} from "interfaces/IYearnVault.sol";
import {CurvePoolInterfaceType} from "interfaces/ICurvePool.sol";

contract YearnCurveSwapper is CurveSwapper {
    using SafeTransferLib for address;

    IYearnVault public immutable wrapper;

    constructor(
        IBentoBoxV1 _bentoBox,
        IYearnVault _wrapper,
        address _mim,
        CurvePoolInterfaceType _curvePoolInterfaceType,
        address _curvePool,
        address _curvePoolDepositor /* Optional Curve Deposit Zapper */,
        address[] memory _poolTokens,
        address _zeroXExchangeProxy
    )
        CurveSwapper(
            _bentoBox,
            _wrapper.token(),
            _mim,
            _curvePoolInterfaceType,
            _curvePool,
            _curvePoolDepositor,
            _poolTokens,
            _zeroXExchangeProxy
        )
    {
        wrapper = _wrapper;
        if (_curvePoolDepositor != address(0)) {
            address curveToken = wrapper.token();
            curveToken.safeApprove(_curvePoolDepositor, type(uint256).max);
        }
    }

    function withdrawFromBentoBox(uint256 shareFrom) internal override returns (uint256 amount) {
        (amount, ) = bentoBox.withdraw(IERC20(address(wrapper)), address(this), address(this), 0, shareFrom);

        // Yearn Vault -> CurveLP token
        amount = wrapper.withdraw();
    }
}
