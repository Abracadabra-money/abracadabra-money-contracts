// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;
import "cauldrons/CauldronV4.sol";
import "interfaces/IRewarder.sol";
import "libraries/compat/BoringMath.sol";
import "BoringSolidity/libraries/BoringRebase.sol";

contract CauldronV4WithRewarder is CauldronV4 {
    using RebaseLibrary for Rebase;
    using BoringMath for uint256;
    using BoringMath128 for uint128;

    IRewarder public rewarder;

    constructor(IBentoBoxV1 bentoBox_, IERC20 magicInternetMoney_) CauldronV4(bentoBox_, magicInternetMoney_) {}

    function setRewarder(IRewarder _rewarder) external {
        require(address(rewarder) == address(0));
        rewarder = _rewarder;
        blacklistedCallees[address(rewarder)] = true;
    }

    function _afterAddCollateral(address user, uint256 collateralShare) internal override {
        rewarder.deposit(user, collateralShare);
    }

    function _afterRemoveCollateral(address user, uint256 collateralShare) internal override {
        rewarder.withdraw(user, collateralShare);
    }

    function _afterUserLiquidated(address user, uint256 collateralShare) internal override {
        rewarder.withdraw(user, collateralShare);
    }
}
