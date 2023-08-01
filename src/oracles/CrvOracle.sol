// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "libraries/MathLib.sol";
import "interfaces/IOracle.sol";
import "interfaces/IAggregator.sol";
import "BoringSolidity/BoringOwnable.sol";

contract CrvOracle is IOracle, BoringOwnable {
    IOracle public constant crvOracle = IOracle(0xE1Ac243F14dE48Eba4C267e82D97EbC7D260D318);
    uint256 public answer;

    constructor () {
        answer = 2857142857140000000;
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function setAnswer(uint256 _answer) public onlyOwner {
        answer = _answer;
    }

    function _get() internal view returns (uint256) {
        (,uint256 crvPrice) = crvOracle.peek(bytes("CRV"));
        return MathLib.min(answer, crvPrice);
    }

    // Get the latest exchange rate
    /// @inheritdoc IOracle
    function get(bytes calldata) public view override returns (bool, uint256) {
        return (true, _get());
    }

    // Check the last exchange rate without any state changes
    /// @inheritdoc IOracle
    function peek(bytes calldata) public view override returns (bool, uint256) {
        return (true, _get());
    }

    // Check the current spot exchange rate without any state changes
    /// @inheritdoc IOracle
    function peekSpot(bytes calldata data) external view override returns (uint256 rate) {
        (, rate) = peek(data);
    }

    /// @inheritdoc IOracle
    function name(bytes calldata) public view override returns (string memory) {
        return "Crv Oracle";
    }

    /// @inheritdoc IOracle
    function symbol(bytes calldata) public view override returns (string memory) {
        return "Crv Oracle";
    }
}
