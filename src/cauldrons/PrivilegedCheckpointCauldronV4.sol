// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {IERC20} from "@BoringSolidity/interfaces/IERC20.sol";
import {PrivilegedCauldronV4} from "/cauldrons/PrivilegedCauldronV4.sol";
import {ICheckpointToken} from "/interfaces/ICheckpointToken.sol";
import {IBentoBoxV1} from "/interfaces/IBentoBoxV1.sol";

contract PrivilegedCheckpointCauldronV4 is PrivilegedCauldronV4 {

    constructor(IBentoBoxV1 bentoBox_, IERC20 magicInternetMoney_, address owner_) PrivilegedCauldronV4(bentoBox_, magicInternetMoney_, owner_) {}

    function addCollateral(address to, bool skim, uint256 share) public override {
        ICheckpointToken(address(collateral)).user_checkpoint(to);
        super.addCollateral(to, skim, share);
    }

    function _removeCollateral(address to, uint256 share) internal override {
        ICheckpointToken(address(collateral)).user_checkpoint(address(msg.sender));
        super._removeCollateral(to, share);
    }

    function _beforeUserLiquidated(
        address user,
        uint256 /* borrowPart */,
        uint256 /* borrowAmount */,
        uint256 /* collateralShare */
    ) internal override {
        ICheckpointToken(address(collateral)).user_checkpoint(user);
    }
}