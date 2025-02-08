// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OwnableRoles} from "@solady/auth/OwnableRoles.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {FeeCollectable} from "/mixins/FeeCollectable.sol";
import {IERC4626} from "/interfaces/IERC4626.sol";
import {IMagicKodiakVault} from "/interfaces/IMagicKodiakVault.sol";
import {IKodiakVaultStaking} from "/interfaces/IKodiak.sol";
import {IKodiakVaultV1, IKodiakVaultStaking, IKodiakV1RouterStaking} from "/interfaces/IKodiak.sol";

/// @notice Contract to harvest rewards from the staking contract and distribute them to the vault
contract MagicKodiakVaultHarvester is OwnableRoles, FeeCollectable {
    using SafeTransferLib for address;

    error ErrSwapFailed();
    event LogExchangeRouterChanged(address indexed previous, address indexed current);
    event LogRouterChanged(address indexed previous, address indexed current);
    event LogHarvest(uint256 total, uint256 amount, uint256 fee);

    struct SwapInfo {
        address token;
        uint256 amount;
        bytes swapData;
    }

    uint256 public constant ROLE_OPERATOR = _ROLE_0;

    IMagicKodiakVault public immutable vault;
    address public immutable asset;
    address public immutable token0;
    address public immutable token1;

    IKodiakV1RouterStaking public router;
    address public exchangeRouter;

    constructor(IMagicKodiakVault _vault, address _owner) {
        vault = _vault;
        _initializeOwner(_owner);

        asset = IERC4626(address(vault)).asset();
        asset.safeApprove(address(vault), type(uint256).max);
        token0 = IKodiakVaultV1(address(asset)).token0();
        token1 = IKodiakVaultV1(address(asset)).token1();
    }

    ////////////////////////////////////////////////////////////////////////////////
    // Operators
    ////////////////////////////////////////////////////////////////////////////////

    function run(SwapInfo[] memory swaps, uint256 amount0, uint256 amount1, uint256 minAmountOut) external onlyOwnerOrRoles(ROLE_OPERATOR) {
        vault.harvest(address(this));

        for (uint i = 0; i < swaps.length; i++) {
            SwapInfo memory swap = swaps[i];

            if (swap.swapData.length > 0) {
                (bool success, ) = exchangeRouter.call(swap.swapData);
                if (!success) {
                    revert ErrSwapFailed();
                }
            }
        }

        uint balanceBefore = asset.balanceOf(address(this));
        router.addLiquidity(IKodiakVaultV1(address(asset)), amount0, amount1, 0, 0, minAmountOut, address(this));

        uint256 totalAmount = asset.balanceOf(address(this)) - balanceBefore;
        (uint256 assetAmount, uint256 feeAmount) = _calculateFees(totalAmount);

        if (feeAmount > 0) {
            asset.safeTransfer(feeCollector, feeAmount);
        }

        vault.distributeRewards(assetAmount);
        emit LogHarvest(totalAmount, assetAmount, feeAmount);
    }

    ////////////////////////////////////////////////////////////////////////////////
    // Admin
    ////////////////////////////////////////////////////////////////////////////////

    function setExchangeRouter(address _exchangeRouter) external onlyOwner {
        IKodiakVaultStaking staking = vault.staking();

        for (uint256 i = 0; i < staking.getAllRewardTokens().length; i++) {
            address reward = staking.rewardTokens(i);

            if (exchangeRouter != address(0)) {
                reward.safeApprove(exchangeRouter, 0);
            }
            reward.safeApprove(_exchangeRouter, type(uint256).max);
        }

        emit LogExchangeRouterChanged(exchangeRouter, _exchangeRouter);
        exchangeRouter = _exchangeRouter;
    }

    function setRouter(IKodiakV1RouterStaking _router) external onlyOwner {
        if (address(router) != address(0)) {
            token0.safeApprove(address(router), 0);
            token1.safeApprove(address(router), 0);
        }

        token0.safeApprove(address(_router), type(uint256).max);
        token1.safeApprove(address(_router), type(uint256).max);

        emit LogRouterChanged(address(router), address(_router));
        router = _router;
    }

    ////////////////////////////////////////////////////////////////////////////////
    // Internals
    ////////////////////////////////////////////////////////////////////////////////

    function _isFeeOperator(address account) internal view override returns (bool) {
        return account == owner();
    }
}
