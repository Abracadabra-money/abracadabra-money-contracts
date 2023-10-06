// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "interfaces/IOracle.sol";
import "interfaces/IGmxReader.sol";
import "interfaces/IAggregator.sol";

contract GmOracleWithAggregator is IOracle {
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
        IAggregator _indexToken,
        IAggregator _shortToken,
        uint256 _expansionFactorIndex,
        uint256 _expansionFactorShort,
        address _market,
        address _dataStore,
        string memory _desc
    ) {
        reader = _reader;
        indexAggregator = _indexToken;
        shortAggregator = _shortToken;
        expansionFactorIndex = _expansionFactorIndex;
        expansionFactorShort = _expansionFactorShort;
        dataStore = _dataStore;
        Market.Props memory props = _reader.getMarket(_dataStore, _market);
        (marketToken, indexToken, longToken, shortToken)  = (props.marketToken, props.indexToken, props.longToken, props.shortToken);
        desc = _desc;
    }

    function decimals() external view returns (uint8) {
        return uint8(18);
    }
    
    function _get() internal view returns (uint256 lpPrice) {
        uint256 indexTokenPrice = uint256(indexAggregator.latestAnswer()) * expansionFactorIndex;
        uint256 shortTokenPrice = uint256(shortAggregator.latestAnswer()) * expansionFactorShort;
        (int256 price, ) = reader.getMarketTokenPrice(
            dataStore, 
            Market.Props(marketToken, indexToken, longToken, shortToken), 
            Price.Props(indexTokenPrice, indexTokenPrice), 
            Price.Props(indexTokenPrice, indexTokenPrice), 
            Price.Props(shortTokenPrice, shortTokenPrice), 
            PNL_TYPE, 
            false);

        // TODO: fix magic numbers and verify for other gm pairs
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
