// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "BoringSolidity/BoringOwnable.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import "BoringSolidity/libraries/BoringRebase.sol";
import "mixins/Operatable.sol";
import "interfaces/IMagicApe.sol";

contract MagicApeHarvestor is Operatable {
    using BoringERC20 for IERC20;

    IMagicApe public immutable magicApe;
    IApeCoinStaking public immutable staking;
    uint64 public lastExecution;

    constructor(IMagicApe _magicApe) {
        magicApe = _magicApe;
        staking = _magicApe.staking();
    }

    function claimable() external view returns (uint256) {
        return staking.pendingRewards(0, address(magicApe), 0);
    }

    function run() external onlyOperators {
        magicApe.harvest();
        lastExecution = uint64(block.timestamp);
    }
}
