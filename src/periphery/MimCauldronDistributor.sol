// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/ERC20.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import "interfaces/ICauldronV4.sol";

contract MimCauldronDistributor {
    ERC20 public immutable mim;
    ICauldronV4 public immutable cauldron;

    constructor(ERC20 _mim, ICauldronV4 _cauldron) {
        mim = _mim;
        cauldron = _cauldron;
    }

    function distribute() external {
        mim.transfer(address(cauldron), mim.balanceOf(address(this)));
        cauldron.repayForAll(
            0, /* amount ignored when skimming */
            true
        );
    }
}
