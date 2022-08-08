// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "BoringSolidity/interfaces/IERC20.sol";
import "withdrawers/MultichainWithdrawer.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/IAnyswapRouter.sol";

abstract contract WithdrawerScript {
    function deployMultichainWithdrawer(
        address bentoBox,
        address degenBox,
        address mim,
        address anyswapRouter,
        address mimProvider,
        address ethereumWithdrawer
    ) public returns (MultichainWithdrawer withdrawer) {
        withdrawer = new MultichainWithdrawer(
            IBentoBoxV1(bentoBox),
            IBentoBoxV1(degenBox),
            ERC20(mim),
            IAnyswapRouter(anyswapRouter),
            mimProvider,
            ethereumWithdrawer,
            new ICauldronV2[](0),
            new ICauldronV1[](0),
            new ICauldronV2[](0)
        );
    }
}
