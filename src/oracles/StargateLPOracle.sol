// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IOracle} from "interfaces/IOracle.sol";
import {IStargatePool} from "interfaces/IStargate.sol";
import {IAggregator} from "interfaces/IAggregator.sol";

contract StargateLPOracle is IOracle {
    IStargatePool public immutable pool;
    IAggregator public immutable tokenAggregator;

    uint256 public immutable decimalScale;
    string private desc;

    constructor(IStargatePool _pool, IAggregator _tokenAggregator, string memory _desc) {
        pool = _pool;
        tokenAggregator = _tokenAggregator;
        desc = _desc;
        decimalScale = 10 ** (_pool.decimals() + _tokenAggregator.decimals());
    }

    function decimals() external view returns (uint8) {
        return uint8(pool.decimals());
    }

    function _get() internal view returns (uint256) {
        uint256 lpPrice = (pool.totalLiquidity() * uint256(tokenAggregator.latestAnswer())) / pool.totalSupply();
        return decimalScale / lpPrice;
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
