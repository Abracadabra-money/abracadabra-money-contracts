// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/BoringOwnable.sol";
import "BoringSolidity/ERC20.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import "interfaces/ICauldronV4.sol";

contract MimCauldronDistributor is BoringOwnable {
    event LogPaused(bool previous, bool current);
    event LogCauldronChanged(ICauldronV4 indexed previous, ICauldronV4 indexed current);

    error ErrPaused();

    ERC20 public immutable mim;
    ICauldronV4 public cauldron;

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

        emit LogCauldronChanged(ICauldronV4(address(0)), _cauldron);
    }

    function distribute() external notPaused {
        mim.transfer(address(cauldron), mim.balanceOf(address(this)));
        cauldron.repayForAll(
            0, /* amount ignored when skimming */
            true
        );
    }

    function setPause(bool _paused) external onlyOwner {
        emit LogPaused(paused, _paused);
        paused = _paused;
    }

    function setCauldron(ICauldronV4 _cauldron) external onlyOwner {
        emit LogCauldronChanged(cauldron, _cauldron);
        cauldron = _cauldron;
    }

    // admin execution
    function execute(
        address to,
        uint256 value,
        bytes calldata data
    ) external onlyOwner returns (bool success, bytes memory result) {
        // solhint-disable-next-line avoid-low-level-calls
        (success, result) = to.call{value: value}(data);
    }
}
