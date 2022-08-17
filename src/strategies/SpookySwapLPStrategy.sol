// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "./MasterChefLPStrategy.sol";

interface ISpookySwapMasterChefV2 {
    function emergencyWithdraw(uint256 _pid, address _to) external;
}

contract SpookySwapLPStrategy is MasterChefLPStrategy {
    constructor(
        IERC20 _strategyToken,
        IBentoBoxV1 _bentoBox,
        address _factory,
        IMasterChef _masterchef,
        uint256 _pid,
        IUniswapV2Router01 _router,
        bytes32 _pairCodeHash
    ) MasterChefLPStrategy(_strategyToken, _bentoBox, _factory, _masterchef, _pid, _router, _pairCodeHash) {}

    function _exit() internal override {
        ISpookySwapMasterChefV2(address(masterchef)).emergencyWithdraw(pid, address(this));
    }
}
