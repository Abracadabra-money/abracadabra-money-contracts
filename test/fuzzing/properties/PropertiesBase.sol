// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "fuzzlib/FuzzBase.sol";
import "fuzzlib/AssertWrapper.sol";
import "./PropertiesDescriptions.sol";
import "../helper/BeforeAfter.sol";

/**
 * @title PropertiesBase
 * @author 0xScourgedev
 * @notice Composite contract for all of the dependencies of the properties
 */
abstract contract PropertiesBase is FuzzBase, BeforeAfter, PropertiesDescriptions {

}
