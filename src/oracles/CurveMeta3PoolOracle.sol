// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "interfaces/IOracle.sol";
import "interfaces/IAggregator.sol";
import "interfaces/ICurvePool.sol";
import "libraries/MathLib.sol";

contract CurveMeta3PoolOracle is IOracle {
    ICurvePool public immutable curvePool;
    IAggregator public immutable tokenOracle;
    IAggregator public immutable daiOracle;
    IAggregator public immutable usdcOracle;
    IAggregator public immutable usdtOracle;
    string private desc;

    /// @notice Construct a new CurveMeta3PoolOracle Oracle
    /// @param _desc The description of the CurveMeta3PoolOracle returned by name() and symbol()
    /// @param _curvePool The CurvePool to query
    /// @param _tokenOracle (Optionnal) The Chainlink oracle for the token. When address(0),
    ///                     the token price is pegged to the other stablecoins.
    /// @param _daiOracle The Chainlink oracle for DAI
    /// @param _usdcOracle The Chainlink oracle for USDC
    /// @param _usdtOracle The Chainlink oracle for USDT
    constructor(
        string memory _desc,
        ICurvePool _curvePool,
        IAggregator _tokenOracle,
        IAggregator _daiOracle,
        IAggregator _usdcOracle,
        IAggregator _usdtOracle
    ) {
        curvePool = _curvePool;
        tokenOracle = _tokenOracle;
        daiOracle = _daiOracle;
        usdcOracle = _usdcOracle;
        usdtOracle = _usdtOracle;
        desc = _desc;
    }

    function _get() internal view returns (uint256) {
        uint256 minStable;

        if (address(tokenOracle) == address(0)) {
            minStable = MathLib.min(
                uint256(daiOracle.latestAnswer()),
                MathLib.min(uint256(usdcOracle.latestAnswer()), uint256(usdtOracle.latestAnswer()))
            );
        } else {
            minStable = MathLib.min(
                uint256(daiOracle.latestAnswer()),
                MathLib.min(
                    uint256(usdcOracle.latestAnswer()),
                    MathLib.min(uint256(usdtOracle.latestAnswer()), uint256(tokenOracle.latestAnswer()))
                )
            );
        }

        return 1e44 / (curvePool.get_virtual_price() * minStable);
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
        return desc;
    }

    /// @inheritdoc IOracle
    function symbol(bytes calldata) public view override returns (string memory) {
        return desc;
    }
}
