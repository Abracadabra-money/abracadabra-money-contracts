// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IOracle} from "interfaces/IOracle.sol";
import {IAggregator} from "interfaces/IAggregator.sol";
import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {BoringERC20} from "BoringSolidity/libraries/BoringERC20.sol";
import {IGmxV2Market, IGmxV2Price, IGmxReader} from "interfaces/IGmxV2.sol";

contract GmOracleWithAggregator is IOracle {
    using BoringERC20 for IERC20;
    bytes32 private constant PNL_TYPE = keccak256(abi.encode("MAX_PNL_FACTOR_FOR_TRADERS"));
    IGmxReader public immutable reader;
    IAggregator public immutable indexAggregator;
    uint256 public immutable expansionFactorIndex;
    uint256 public immutable expansionFactorShort;
    IAggregator public immutable shortAggregator;
    address public immutable dataStore;
    address immutable marketToken;
    address immutable indexToken;
    address immutable longToken;
    address immutable shortToken;

    string private desc;

    constructor(
        IGmxReader _reader,
        IAggregator _indexTokenAggregator,
        IAggregator _shortTokenAggregator,
        address _market,
        address _indexToken,
        address _dataStore,
        string memory _desc
    ) {
        reader = _reader;
        indexAggregator = _indexTokenAggregator;
        shortAggregator = _shortTokenAggregator;
        indexToken = _indexToken;
        dataStore = _dataStore;
        IGmxV2Market.Props memory props = _reader.getMarket(_dataStore, _market);
        (marketToken, , longToken, shortToken) = (props.marketToken, props.indexToken, props.longToken, props.shortToken);

        // GMX uses an internal precision of 1e30
        expansionFactorIndex = 10 ** (30 - indexAggregator.decimals() - IERC20(indexToken).safeDecimals());
        expansionFactorShort = 10 ** (30 - shortAggregator.decimals() - IERC20(shortToken).safeDecimals());
        desc = _desc;
    }

    function decimals() external pure returns (uint8) {
        return uint8(18);
    }

    function _get() internal view returns (uint256 lpPrice) {
        uint256 indexTokenPrice = uint256(indexAggregator.latestAnswer()) * expansionFactorIndex;
        uint256 shortTokenPrice = uint256(shortAggregator.latestAnswer()) * expansionFactorShort;

        (int256 price, ) = reader.getMarketTokenPrice(
            dataStore,
            IGmxV2Market.Props(marketToken, indexToken, longToken, shortToken),
            IGmxV2Price.Props(indexTokenPrice, indexTokenPrice),
            IGmxV2Price.Props(indexTokenPrice, indexTokenPrice),
            IGmxV2Price.Props(shortTokenPrice, shortTokenPrice),
            PNL_TYPE,
            false
        );

        // GMX uses an internal precision of 1e30
        lpPrice = (1e18 * 1e30) / uint256(price);
    }

    /// @inheritdoc IOracle
    function get(bytes calldata) public view override returns (bool, uint256) {
        return (true, _get());
    }

    /// @inheritdoc IOracle
    function peek(bytes calldata) public view override returns (bool, uint256) {
        return (true, _get());
    }

    /// @inheritdoc IOracle
    function peekSpot(bytes calldata data) external view override returns (uint256 rate) {
        (, rate) = peek(data);
    }

    /// @inheritdoc IOracle
    function name(bytes calldata) public view override returns (string memory) {
        return desc;
    }

    /// @inheritdoc IOracle
    function symbol(bytes calldata) public view override returns (string memory) {
        return desc;
    }
}
