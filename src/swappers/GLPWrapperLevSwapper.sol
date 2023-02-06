// SPDX-License-Identifier: MIT
// solhint-disable avoid-low-level-calls
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import "libraries/SafeApprove.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/ILevSwapperV2.sol";
import "interfaces/ITokenWrapper.sol";
import "interfaces/IGmxGlpRewardRouter.sol";
import "interfaces/IGmxVault.sol";

contract GLPWrapperLevSwapper is ILevSwapperV2 {
    using BoringERC20 for IERC20;
    using SafeApprove for IERC20;

    error ErrSwapFailed();

    IBentoBoxV1 public immutable bentoBox;
    IERC20 public immutable mim;
    IERC20 public immutable wrappedGlp;
    IGmxGlpRewardRouter public immutable rewardRouter;
    IERC20 public immutable sGLP;
    address public immutable zeroXExchangeProxy;
    IGmxVault public immutable gmxVault;

    constructor(
        IBentoBoxV1 _bentoBox,
        IGmxVault _gmxVault,
        IERC20 _wrappedGlp,
        IERC20 _mim,
        IERC20 _sGLP,
        address glpManager,
        IGmxGlpRewardRouter _rewardRouter,
        address _zeroXExchangeProxy
    ) {
        bentoBox = _bentoBox;
        gmxVault = _gmxVault;
        wrappedGlp = _wrappedGlp;
        mim = _mim;

        zeroXExchangeProxy = _zeroXExchangeProxy;
        rewardRouter = _rewardRouter;
        sGLP = _sGLP;

        uint256 len = _gmxVault.allWhitelistedTokensLength();
        for (uint256 i = 0; i < len; i++) {
            IERC20 token = IERC20(_gmxVault.allWhitelistedTokens(i));
            if (token == mim) continue;
            token.safeApprove(glpManager, type(uint256).max);
        }

        _wrappedGlp.approve(address(_bentoBox), type(uint256).max);
        _sGLP.approve(address(_wrappedGlp), type(uint256).max);
        _mim.approve(_zeroXExchangeProxy, type(uint256).max);
    }

    /// @inheritdoc ILevSwapperV2
    function swap(
        address recipient,
        uint256 shareToMin,
        uint256 shareFrom,
        bytes calldata data
    ) external override returns (uint256 extraShare, uint256 shareReturned) {
        (bytes memory swapData, IERC20 token) = abi.decode(data, (bytes, IERC20));
        bentoBox.withdraw(mim, address(this), address(this), 0, shareFrom);

        // MIM -> token
        (bool success, ) = zeroXExchangeProxy.call(swapData);
        if (!success) {
            revert ErrSwapFailed();
        }

        uint256 _amount = token.balanceOf(address(this));

        _amount = rewardRouter.mintAndStakeGlp(address(token), _amount, 0, 0);

        ITokenWrapper(address(wrappedGlp)).wrap(_amount);
        _amount = wrappedGlp.balanceOf(address(this));

        (, shareReturned) = bentoBox.deposit(wrappedGlp, address(this), recipient, _amount, 0);
        extraShare = shareReturned - shareToMin;
    }
}
