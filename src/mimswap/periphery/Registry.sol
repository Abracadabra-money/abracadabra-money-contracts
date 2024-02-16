// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {OperatableV2} from "mixins/OperatableV2.sol";
import {IMagicLP} from "/mimswap/interfaces/IMagicLP.sol";
import {MagicLP} from "/mimswap/MagicLP.sol";

/// @notice Simple registry for MagicLPs. Lookups will work irrespective of base/quote token order.
contract Registry is OperatableV2 {
    event LogRegister(address pool_, address indexed baseToken_, address indexed quoteToken_, address indexed creator_);

    error ErrAlreadyRegistered(address pool_);

    mapping(address => bool) public registered;
    mapping(bytes32 => address[]) public pools;
    mapping(address => address[]) public creators;

    constructor(address owner_) OperatableV2(owner_) {}

    //////////////////////////////////////////////////////////////////////////////////////
    /// VIEWS
    //////////////////////////////////////////////////////////////////////////////////////

    function get(address tokenA_, address tokenB_, uint256 index_) external view returns (address) {
        return pools[identifier(tokenA_, tokenB_)][index_];
    }

    function get(bytes32 identifier_, uint256 index_) external view returns (address) {
        return pools[identifier_][index_];
    }

    function count(address tokenA_, address tokenB_) external view returns (uint256) {
        return pools[identifier(tokenA_, tokenB_)].length;
    }

    function count(bytes32 identifier_) external view returns (uint256) {
        return pools[identifier_].length;
    }

    function identifier(address tokenA_, address tokenB_) public pure returns (bytes32 identfier) {
        if (uint160(address(tokenA_)) > uint160(address(tokenB_))) {
            identfier = keccak256(abi.encode(tokenA_, tokenB_));
        } else {
            identfier = keccak256(abi.encode(tokenB_, tokenA_));
        }
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// OPERATORS
    //////////////////////////////////////////////////////////////////////////////////////

    function register(address pool_, address creator_) external onlyOperators returns (bytes32 identifier_) {
        if (registered[pool_]) {
            revert ErrAlreadyRegistered(pool_);
        }

        address baseToken = IMagicLP(pool_)._BASE_TOKEN_();
        address quoteToken = IMagicLP(pool_)._QUOTE_TOKEN_();

        identifier_ = identifier(baseToken, quoteToken);
        pools[identifier_].push(pool_);
        creators[creator_].push(pool_);
        registered[pool_] = true;

        emit LogRegister(pool_, baseToken, quoteToken, creator_);
    }
}
