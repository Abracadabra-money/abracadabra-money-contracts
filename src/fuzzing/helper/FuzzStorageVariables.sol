// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "../util/FuzzConstants.sol";
import "../mocks/MockWETH.sol";
import "../../mimswap/periphery/Factory.sol";
import "../../mimswap/periphery/Router.sol";
import "../../mimswap/MagicLP.sol";
import "../../mimswap/auxiliary/FeeRateModelImpl.sol";
import "../../mimswap/auxiliary/FeeRateModel.sol";

/**
 * @title FuzzStorageVariables
 * @author 0xScourgedev
 * @notice Contains all of the storage variables for the fuzzing suite
 */
abstract contract FuzzStorageVariables is FuzzConstants {
    // Echidna settings
    bool internal _setActor = true;

    // All of the deployed contracts
    Factory internal factory;
    Router internal router;
    MagicLP[] internal markets;
    MagicLP internal marketImpl;
    FeeRateModelImpl internal feeRateModelImpl;
    FeeRateModel internal feeRateModel;

    MockWETH internal weth;
    MockERC20 internal tokenA18;
    MockERC20 internal tokenB18;
    MockERC20 internal tokenA6;
    MockERC20 internal tokenB6;
    MockERC20 internal tokenA8;
    MockERC20 internal tokenB8;
    MockERC20 internal tokenA24;
    MockERC20 internal tokenB24;

    MockERC20[] internal tokens;

    // baseToken => quoteToken => pool
    mapping(address => mapping(address => address)) internal pools;
    // baseToken => array of possible quoteTokens
    mapping(address => address[]) internal availablePools;
    address[] internal allPools;

    address internal currentActor;
}
