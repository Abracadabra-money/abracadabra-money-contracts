// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {MockERC20} from "BoringSolidity/mocks/MockERC20.sol";
import {TimestampStore} from "../stores/TimestampStore.sol";
import "forge-std/Test.sol";

/// @notice Base contract with common logic needed by all handler contracts.
abstract contract BaseHandler is Test {
    /*//////////////////////////////////////////////////////////////////////////
                                     CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/
    address[] public actors = [address(0x01), address(0x02)];

    address internal currentActor;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Default ERC-20 token used for testing.
    MockERC20 public token;

    /// @dev Reference to the timestamp store, which is needed for simulating the passage of time.
    TimestampStore public timestampStore;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    constructor(MockERC20 token_, TimestampStore timestampStore_) {
        token = token_;
        timestampStore = timestampStore_;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Simulates the passage of time. The time jump is upper bounded so that streams don't settle too quickly.
    /// See https://github.com/foundry-rs/foundry/issues/4994.
    /// @param timeJumpSeed A fuzzed value needed for generating random time warps.
    modifier adjustTimestamp(uint256 timeJumpSeed) {
        uint256 timeJump = _bound(timeJumpSeed, 3 days, 14 weeks);
        timestampStore.increaseCurrentTimestamp(timeJump);
        vm.warp(timestampStore.currentTimestamp());
        _;
    }

    modifier useCurrentTimestamp() {
        vm.warp(timestampStore.currentTimestamp());
        _;
    }

    /// @dev Makes the provided sender the caller.
    modifier useNewSender(address sender) {
        vm.startPrank(sender);
        _;
        vm.stopPrank();
    }

    /// @dev Selects the actor which is to be the msg.sender.
    modifier useActor(uint256 actorIndexSeed) {
        currentActor = actors[bound(actorIndexSeed, 0, actors.length - 1)];
        vm.startPrank(currentActor);
        _;
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     Functions
    //////////////////////////////////////////////////////////////////////////*/

    function allActors() public view returns (address[] memory) {
        return actors;
    }

    function _random(uint256 min, uint256 max) internal view returns (uint256 amount) {
        amount = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, block.number))) % (max - min + 1) + min;
        return amount;
    }
}
