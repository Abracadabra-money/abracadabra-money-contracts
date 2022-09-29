// SPDX-License-Identifier: MIT
// solhint-disable avoid-low-level-calls
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/ILevSwapperV2.sol";
import "interfaces/ICauldronV2.sol";
import "interfaces/IGmxRewardRouterV2.sol";

contract GmxLevSwapper is ILevSwapperV2 {
    using BoringERC20 for IERC20;

    error ErrSwapFailed();

    bytes4 private constant APPROVE_SIG = 0x095ea7b3;

    IBentoBoxV1 public immutable bentoBox;
    IERC20 public immutable mim;
    IERC20 public immutable fsGPL;
    address public immutable swapAggregator;
    IGmxRewardRouterV2 public immutable rewardRouter;

    constructor(
        IBentoBoxV1 _bentoBox,
        IERC20 _fsGLP,
        IERC20 _mim,
        address _swapAggregator,
        IGmxRewardRouterV2 _rewardRouter
    ) {
        bentoBox = _bentoBox;
        fsGPL = _fsGLP;
        mim = _mim;
        swapAggregator = _swapAggregator;
        rewardRouter = _rewardRouter;

        //_fsGLP.approve(address(_bentoBox), type(uint256).max);
        _mim.approve(_swapAggregator, type(uint256).max);
    }

    /// @inheritdoc ILevSwapperV2
    function swap(
        address recipient,
        uint256 shareToMin,
        uint256 shareFrom,
        bytes calldata data
    ) external override returns (uint256 extraShare, uint256 shareReturned) {
        // tokenOut is the token GLP is going to be minted with
        (bytes memory swapData, IERC20 tokenOut, uint256 minGlp) = abi.decode(data, (bytes, IERC20, uint256));

        bentoBox.withdraw(mim, address(this), address(this), 0, shareFrom);

        // MIM -> tokenOut
        (bool success, ) = swapAggregator.call(swapData);
        if (!success) {
            revert ErrSwapFailed();
        }

        uint256 tokenOutAmount = tokenOut.balanceOf(address(this));
        tokenOut.safeTransfer(msg.sender, tokenOutAmount);


        //(, shareReturned) = bentoBox.deposit(token, address(this), recipient, token.balanceOf(address(this)), 0);
        //extraShare = shareReturned - shareToMin;
    }
}
