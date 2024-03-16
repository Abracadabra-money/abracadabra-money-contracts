// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./FuzzFactory.sol";
import "./FuzzRouter.sol";
import "./FuzzMagicLP.sol";

/**
 * @title Fuzz
 * @author 0xScourgedev
 * @notice Composite contract for all of the handlers
 */
contract Fuzz is FuzzFactory, FuzzRouter, FuzzMagicLP {
    constructor() payable {
        setup();
        setupActors();
    }
}
