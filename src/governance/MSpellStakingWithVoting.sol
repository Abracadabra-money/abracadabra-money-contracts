// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {MSpellStaking} from "staking/MSpellStaking.sol";

contract MSpellStakingWithVoting is MSpellStaking, ERC20, ERC20Permit, ERC20Votes {
    constructor(
        address _mim,
        address _spell,
        address _owner
    ) MSpellStaking(_mim, _spell, _owner) ERC20("mSPELL", "mSPELL") ERC20Permit("mSpell") {}

    function _afterDeposit(address _user, uint256 _amount) internal override {
        _mint(_user, _amount);
    }

    function _afterWithdraw(address _user, uint256 _amount) internal override {
        _burn(_user, _amount);
    }

    function transfer(address, uint256) public virtual override returns (bool) {
        revert ErrUnsupportedOperation();
    }

    function transferFrom(address, address, uint256) public virtual override returns (bool) {
        revert ErrUnsupportedOperation();
    }

    function approve(address, uint256) public virtual override returns (bool) {
        revert ErrUnsupportedOperation();
    }

    function _update(address from, address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._update(from, to, amount);
    }

    function nonces(address owner) public view virtual override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
