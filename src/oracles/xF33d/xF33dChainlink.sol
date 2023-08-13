// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "mixins/LzNonblockingApp.sol";
import "interfaces/AggregatorV3Interface.sol";

contract xF33dChainlink is LzNonblockingApp {
    struct OracleDataStruct {
        uint80 roundId;
        int256 answer;
        uint256 startedAt;
        uint256 updatedAt;
        uint80 answeredInRound;
    }

    mapping(bytes32 => OracleDataStruct) public oracleData;
    mapping(bytes32 => uint8) public decimals;

    constructor(address _lzEndpoint) LzNonblockingApp(_lzEndpoint) {}

    function sendUpdatedRate(uint16 _chainId, address _feed) external payable {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = AggregatorV3Interface(_feed)
            .latestRoundData();

        bytes memory _payload = abi.encode(_feed, roundId, answer, startedAt, updatedAt, answeredInRound);

        _lzSend(_chainId, _payload, payable(msg.sender), address(0), bytes(""), msg.value);
    }

    function _nonblockingLzReceive(uint16 _srcChainId, bytes memory, uint64, bytes memory _payload, bool) internal override {
        (address _feed, OracleDataStruct memory od) = abi.decode(_payload, (address, OracleDataStruct));
        oracleData[keccak256(abi.encode(_srcChainId, _feed))] = od;
    }

    function setDecimal(bytes32 _feedHash, uint8 _decimal) public onlyOwner {
        decimals[_feedHash] = _decimal;
    }

    function latestAnswer(bytes32 _feedHash) external view returns (int256) {
        OracleDataStruct memory od = oracleData[_feedHash];
        return (od.answer);
    }

    function latestRoundData(bytes32 _feedHash) external view returns (uint80, int256, uint256, uint256, uint80) {
        OracleDataStruct memory od = oracleData[_feedHash];
        return (od.roundId, od.answer, od.startedAt, od.updatedAt, od.answeredInRound);
    }
}
