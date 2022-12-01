// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/ERC20.sol";
import "BoringSolidity/BoringOwnable.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import "interfaces/ICauldronV4.sol";
import "interfaces/IMimCauldronDistributor.sol";

contract MimCauldronDistributor is BoringOwnable, IMimCauldronDistributor {
    event LogPaused(bool previous, bool current);
    error ErrPaused();

    ERC20 public immutable mim;
    ICauldronV4 public immutable cauldron;
    bool public paused;

    modifier notPaused() {
        if (paused) {
            revert ErrPaused();
        }
        _;
    }

    constructor(ERC20 _mim, ICauldronV4 _cauldron) {
        mim = _mim;
        cauldron = _cauldron;
    }

    function distribute() external notPaused {
        uint256 amount = mim.balanceOf(address(this));

        Rebase memory totalBorrow = cauldron.totalBorrow();
        if (amount > totalBorrow.elastic) {
            amount = totalBorrow.elastic;
        }

        mim.transfer(address(cauldron), amount);

        cauldron.repayForAll(
            0, /* amount ignored when skimming */
            true
        );
    }

    function setPaused(bool _paused) external onlyOwner {
        emit LogPaused(paused, _paused);
        paused = _paused;
    }

    function withdraw() external onlyOwner {
        mim.transfer(owner, mim.balanceOf(address(this)));
    }
}
