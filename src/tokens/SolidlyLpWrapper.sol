// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "tokens/ERC20Vault.sol";
import "interfaces/ISolidlyPair.sol";
import "interfaces/ISolidlyRouter.sol";
import "interfaces/ISolidlyLpWrapper.sol";
import "interfaces/IVelodromePairFactory.sol";
import "libraries/SolidlyOneSidedVolatile.sol";
import "libraries/SafeTransferLib.sol";

contract SolidlyLpWrapper is ERC20Vault, ISolidlyLpWrapper {
    using SafeTransferLib for IERC20;

    ISolidlyPair public immutable pair;
    address public immutable token0;
    address public immutable token1;

    constructor(
        ISolidlyPair _pair,
        string memory _name,
        string memory _symbol,
        uint8 decimals
    ) ERC20Vault(IERC20(address(_pair)), _name, _symbol, decimals) {
        pair = _pair;
        (token0, token1) = _pair.tokens();
    }

    function _beforeHarvest(IVaultHarvester harvester) internal override {
        ISolidlyPair(address(underlying)).claimFees();
        IERC20(token0).safeTransfer(address(harvester), IERC20(token0).balanceOf(address(this)));
        IERC20(token1).safeTransfer(address(harvester), IERC20(token1).balanceOf(address(this)));
    }
}
