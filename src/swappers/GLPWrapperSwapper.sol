// SPDX-License-Identifier: MIT
// solhint-disable avoid-low-level-calls
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import "libraries/SafeApprove.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/ISwapperV2.sol";
import "interfaces/IGmxRewardRouterV2.sol";
import "interfaces/ITokenWrapper.sol";
import "interfaces/IGmxVault.sol";

contract GLPWrapperSwapper is ISwapperV2 {
    using BoringERC20 for IERC20;
    using SafeApprove for IERC20;

    error ErrSwapFailed();

    IBentoBoxV1 public immutable bentoBox;
    IERC20 public immutable wrappedGlp;
    IERC20 public immutable mim;
    IERC20 public immutable sGLP;
    IGmxRewardRouterV2 public immutable rewardRouter;
    address public immutable zeroXExchangeProxy;
    IGmxVault public immutable gmxVault;

    constructor(
        IBentoBoxV1 _bentoBox,
        IGmxVault _gmxVault,
        IERC20 _wrappedGlp,
        IERC20 _mim,
        IERC20 _sGLP,
        IGmxRewardRouterV2 _rewardRouter,
        address _zeroXExchangeProxy
    ) {
        bentoBox = _bentoBox;
        gmxVault = _gmxVault;
        wrappedGlp = _wrappedGlp;
        mim = _mim;
        sGLP = _sGLP;
        rewardRouter = _rewardRouter;
        zeroXExchangeProxy = _zeroXExchangeProxy;

        uint256 len = _gmxVault.allWhitelistedTokensLength();
        for (uint256 i = 0; i < len; i++) {
            IERC20 token = IERC20(_gmxVault.allWhitelistedTokens(i));
            if (token == mim) continue;
            token.safeApprove(_zeroXExchangeProxy, type(uint256).max);
        }

        mim.approve(address(_bentoBox), type(uint256).max);
    }

    /// @inheritdoc ISwapperV2
    function swap(
        address,
        address,
        address recipient,
        uint256 shareToMin,
        uint256 shareFrom,
        bytes calldata data
    ) public override returns (uint256 extraShare, uint256 shareReturned) {
        (bytes memory swapData, IERC20 token) = abi.decode(data, (bytes, IERC20));

        (uint256 amount, ) = bentoBox.withdraw(IERC20(address(wrappedGlp)), address(this), address(this), 0, shareFrom);
        ITokenWrapper(address(wrappedGlp)).unwrap(amount);

        rewardRouter.unstakeAndRedeemGlp(address(token), amount, 0, address(this));

        // token -> MIM
        (bool success, ) = zeroXExchangeProxy.call(swapData);
        if (!success) {
            revert ErrSwapFailed();
        }

        // we can expect dust from both gmx and 0x
        token.safeTransfer(recipient, token.balanceOf(address(this)));

        (, shareReturned) = bentoBox.deposit(mim, address(this), recipient, mim.balanceOf(address(this)), 0);
        extraShare = shareReturned - shareToMin;
    }
}
