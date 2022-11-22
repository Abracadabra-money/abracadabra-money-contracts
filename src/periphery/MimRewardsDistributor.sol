// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/BoringOwnable.sol";
import "BoringSolidity/ERC20.sol";
import "BoringSolidity/libraries/BoringERC20.sol";

/// @notice basic simple mim reward distributor
/// To be improved to support per-address mim distribution allocations
contract MimRewardDistributor is BoringOwnable {
    event LogPaused(bool previous, bool current);

    error ErrPaused();

    ERC20 public immutable mim;
    address public immutable recipient;

    bool public paused;

    modifier notPaused() {
        if (paused) {
            revert ErrPaused();
        }
        _;
    }

    constructor(ERC20 _mim, address _recipient) {
        mim = _mim;
        recipient = _recipient;
    }

    function distribute() external notPaused {
        mim.transfer(recipient, mim.balanceOf(address(this)));
    }

    function setPause(bool _paused) external onlyOwner {
        emit LogPaused(paused, _paused);
        paused = _paused;
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
