// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "mixins/LzNonblockingApp.sol";
import "interfaces/IAggregator.sol";

/**
 * @title XF33dOracle
 * @author sarangparikh22
 * @dev A decentralized oracle contract that uses Chainlink to get price feeds from various blockchains.
 */
contract XF33dOracle is LzNonblockingApp {
    struct OracleData {
        uint80 roundId;
        int256 answer;
        uint256 startedAt;
        uint256 updatedAt;
        uint80 answeredInRound;
    }

    mapping(bytes32 => OracleData) public oracleData;
    mapping(bytes32 => uint8) public decimals;

    event FeedUpdateSent(uint16 indexed _chainId, address indexed _feed);
    event FeedUpdateReceived(uint16 indexed _srcChainId, address indexed _feed, bytes32 indexed feedHash);

    error ArrayLengthMismatch();

    constructor(address _lzEndpoint, address _owner) LzNonblockingApp(_lzEndpoint, _owner) {}

    /**
     * @notice Sends an updated price feed to another chain.
     * @param _chainId The chain ID of the destination chain.
     * @param _feed The address of the chainlink feed.
     */
    function sendUpdatedRate(uint16 _chainId, address _feed) external payable {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = IAggregator(_feed)
            .latestRoundData();

        bytes memory _payload = abi.encode(_feed, roundId, answer, startedAt, updatedAt, answeredInRound);

        _lzSend(_chainId, _payload, payable(msg.sender), address(0), bytes(""), msg.value);

        emit FeedUpdateSent(_chainId, _feed);
    }

    /**
     * @notice Sends an updated price feed to another chain multiple.
     * @param _chainIds The chain IDs of the destination chain.
     * @param _feeds The address of the chainlink feeds.
     */
    function sendUpdatedRateMulti(uint16[] calldata _chainIds, address[] calldata _feeds) external payable {
        uint256 n = _chainIds.length;

        if (n != _feeds.length) revert ArrayLengthMismatch();

        for (uint256 i; i < n; i = _increment(i)) {
            (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = IAggregator(_feeds[i])
                .latestRoundData();

            _lzSend(
                _chainIds[i],
                abi.encode(_feeds[i], roundId, answer, startedAt, updatedAt, answeredInRound),
                payable(msg.sender),
                address(0),
                bytes(""),
                msg.value
            );

            emit FeedUpdateSent(_chainIds[i], _feeds[i]);
        }
    }

    /**
     * @notice Returns the latest answer for a particular feed.
     * @param _feedHash The feed hash.
     * @return The latest answer for the feed.
     */
    function latestAnswer(bytes32 _feedHash) external view returns (int256) {
        OracleData memory od = oracleData[_feedHash];
        return (od.answer);
    }

    /**
     * @notice Returns the latest round data for a particular feed.
     * @param _feedHash The feed hash.
     * @return The roundId The round ID of the latest round of data for the feed.
     * @return The answer The answer from the Chainlink aggregator for the latest round of data.
     * @return The startedAt The Unix timestamp at which the latest round of data was started.
     * @return The updatedAt The Unix timestamp at which the latest round of data was updated.
     * @return The answeredInRound The round ID in which the Chainlink aggregator answered the latest round of data.
     */
    function latestRoundData(bytes32 _feedHash) external view returns (uint80, int256, uint256, uint256, uint80) {
        OracleData memory od = oracleData[_feedHash];
        return (od.roundId, od.answer, od.startedAt, od.updatedAt, od.answeredInRound);
    }

    /**
     * @notice Returns the hash of a feed.
     * @param _srcChainId The chain ID of the source chain.
     * @param _feed The address of the feed.
     * @return The feed hash.
     */
    function getFeedHash(uint16 _srcChainId, address _feed) public pure returns (bytes32) {
        return keccak256(abi.encode(_srcChainId, _feed));
    }

    /**
     * @notice Returns fees for updating fee.
     * @param _chainId The chain ID of the dst chain.
     * @param _feed The address of the feed.
     * @return The fees to be paid for update.
     */
    function getFeesForFeedUpdate(uint16 _chainId, address _feed) public view returns (uint256) {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = IAggregator(_feed)
            .latestRoundData();

        bytes memory _payload = abi.encode(_feed, roundId, answer, startedAt, updatedAt, answeredInRound);
        (uint256 fees, ) = lzEndpoint.estimateFees(_chainId, address(this), _payload, false, bytes(""));
        return fees;
    }

    /**
     * @notice Returns fees for updating fee multiple.
     * @param _chainIds The chain IDs of the dst chain.
     * @param _feeds The address of the feeds.
     * @return The fees to be paid for update.
     */
    function getFeesForFeedUpdateMulti(uint16[] calldata _chainIds, address[] calldata _feeds) public view returns (uint256) {
        uint256 feesFinal;

        uint256 n = _chainIds.length;

        if (n != _feeds.length) revert ArrayLengthMismatch();

        for (uint256 i; i < n; i = _increment(i)) {
            (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = IAggregator(_feeds[i])
                .latestRoundData();

            (uint256 fees, ) = lzEndpoint.estimateFees(
                _chainIds[i],
                address(this),
                abi.encode(_feeds[i], roundId, answer, startedAt, updatedAt, answeredInRound),
                false,
                bytes("")
            );

            feesFinal += fees;
        }

        return feesFinal;
    }

    function _nonblockingLzReceive(uint16 _srcChainId, bytes memory, uint64, bytes memory _payload, bool) internal override {
        (address _feed, OracleData memory od) = abi.decode(_payload, (address, OracleData));
        bytes32 feedHash = keccak256(abi.encode(_srcChainId, _feed));
        oracleData[feedHash] = od;
        emit FeedUpdateReceived(_srcChainId, _feed, feedHash);
    }

    function _increment(uint256 i) internal pure returns (uint256) {
        unchecked {
            return i + 1;
        }
    }

    ///////////////////////////////////////////////////////////////////////
    // Admin
    ///////////////////////////////////////////////////////////////////////

    /**
     * @notice Sets the decimals for a particular feed.
     * @param _feedHash The feed hash.
     * @param _decimal The number of decimals in the feed.
     */
    function setDecimal(bytes32 _feedHash, uint8 _decimal) external onlyOwner {
        decimals[_feedHash] = _decimal;
    }
}
