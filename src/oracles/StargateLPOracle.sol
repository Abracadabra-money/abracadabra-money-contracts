// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "interfaces/IOracle.sol";
import "interfaces/IStargatePool.sol";
import "interfaces/IAggregator.sol";

contract StargateLPOracle is IOracle {
    IStargatePool public immutable pool;
    IAggregator public immutable tokenOracle;

    uint256 public immutable denominator;
    string private desc;

    constructor(
        IStargatePool _pool,
        IAggregator _tokenOracle,
        string memory _desc
    ) {
        pool = _pool;
        tokenOracle = _tokenOracle;
        desc = _desc;
        denominator = 10**(_pool.decimals() + _tokenOracle.decimals());
    }

    function _get() internal view returns (uint256) {
        uint256 lpPrice = (pool.totalLiquidity() * uint256(tokenOracle.latestAnswer())) / pool.totalSupply();

        return denominator / lpPrice;
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
