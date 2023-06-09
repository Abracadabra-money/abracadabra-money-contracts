// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "interfaces/ICurveMeta3PoolOrale.sol";
import "interfaces/IYearnVault.sol";
import "interfaces/ICurvePool.sol";

/// @notice Yearn oracle version of CurveMeta3PoolOracle
contract YearnCurveMeta3PoolOracle is IOracle {
    ICurveMeta3PoolOrale public immutable curveMeta3PoolOracle;
    IYearnVault public immutable vault;
    string private desc;

    constructor(IYearnVault _vault, ICurveMeta3PoolOrale _curveMeta3PoolOracle, string memory _desc) {
        assert(_vault.token() == _curveMeta3PoolOracle.curvePool());
        assert(_vault.decimals() == 18);
        assert(ICurvePool(_curveMeta3PoolOracle.curvePool()).decimals() == 18);

        vault = _vault;
        curveMeta3PoolOracle = _curveMeta3PoolOracle;
        desc = _desc;
    }

    function _get() internal view returns (uint256) {
        uint256 curve3poolPrice = 1e36 / curveMeta3PoolOracle.peekSpot("");
        return 1e54 / (curve3poolPrice * vault.pricePerShare());
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
