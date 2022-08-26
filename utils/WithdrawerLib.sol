// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "BoringSolidity/interfaces/IERC20.sol";
import "periphery/MultichainWithdrawer.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/IAnyswapRouter.sol";

library WithdrawerLib {
    function deployMultichainWithdrawer(
        IBentoBoxV1 bentoBox,
        IBentoBoxV1 degenBox,
        IERC20 mim,
        IAnyswapRouter anyswapRouter,
        address mimProvider,
        address ethereumWithdrawer
    ) internal returns (MultichainWithdrawer withdrawer) {
        withdrawer = new MultichainWithdrawer(
            bentoBox,
            degenBox,
            mim,
            anyswapRouter,
            mimProvider,
            ethereumWithdrawer,
            new ICauldronV2[](0),
            new ICauldronV1[](0),
            new ICauldronV2[](0)
        );
    }
}
