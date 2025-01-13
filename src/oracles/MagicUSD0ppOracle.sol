// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {ERC4626Oracle} from "/oracles/ERC4626Oracle.sol";
import {IERC4626} from "/interfaces/IERC4626.sol";
import {IAggregator} from "/interfaces/IAggregator.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract MagicUSD0ppOracle is ERC4626Oracle {
    address public constant VAULT = 0x73075fD1522893D9dC922991542f98F08F2c1C99;
    address public constant CHAINLINK_USD0PP_AGGREGATOR = 0xFC9e30Cf89f8A00dba3D34edf8b65BCDAdeCC1cB;
    uint256 public constant UPPER_BOUNDARY = 1e8;

    constructor() ERC4626Oracle("MagicUSD0++/USD", IERC4626(VAULT), IAggregator(CHAINLINK_USD0PP_AGGREGATOR)) {}

    function _get() internal view override returns (uint256) {
        return decimalScale / vault.convertToAssets(uint256(Math.min(UPPER_BOUNDARY, uint256(aggregator.latestAnswer()))));
    }
}
