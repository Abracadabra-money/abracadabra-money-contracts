// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {IBentoBoxLite} from "/interfaces/IBentoBoxV1.sol";

interface IExchangeRouter {
    struct CreateWithdrawalParams {
        address receiver;
        address callbackContract;
        address uiFeeReceiver;
        address market;
        address[] longTokenSwapPath;
        address[] shortTokenSwapPath;
        uint256 minLongTokenAmount;
        uint256 minShortTokenAmount;
        bool shouldUnwrapNativeToken;
        uint256 executionFee;
        uint256 callbackGasLimit;
    }

    struct SetPricesParams {
        address[] tokens;
        address[] providers;
        bytes[] data;
    }

    function sendTokens(address token, address receiver, uint256 amount) external payable;

    function sendWnt(address receiver, uint256 amount) external payable;

    function executeAtomicWithdrawal(CreateWithdrawalParams calldata params, SetPricesParams calldata oracleParams) external payable;
}

contract GMSwapper {
    using SafeTransferLib for address;
    using Address for address;

    IBentoBoxLite public immutable box;
    address public immutable mim;
    IExchangeRouter public immutable exchangeRouter;
    address public immutable router;
    address public immutable withdrawalVault;
    address public immutable dataStore;

    struct SwapData {
        address token;
        address to;
        bytes data;
    }

    constructor(
        IBentoBoxLite _box,
        address _mim,
        IExchangeRouter _exchangeRouter,
        address _router,
        address _withdrawalVault,
        address _dataStore
    ) {
        box = _box;
        mim = _mim;
        exchangeRouter = _exchangeRouter;
        router = _router;
        withdrawalVault = _withdrawalVault;
        dataStore = _dataStore;

        _mim.safeApprove(address(_box), type(uint256).max);
    }

    function swap(
        address fromToken,
        address /*toToken*/,
        address recipient,
        uint256 shareToMin,
        uint256 shareFrom,
        bytes calldata data
    ) external payable returns (uint256 extraShare, uint256 shareReturned) {
        (uint256 amount, ) = box.withdraw(fromToken, address(this), address(this), 0, shareFrom);
        (SwapData[] memory swapData, IExchangeRouter.SetPricesParams memory setPricesParams) = abi.decode(
            data,
            (SwapData[], IExchangeRouter.SetPricesParams)
        );

        if (IERC20(fromToken).allowance(address(this), router) != type(uint256).max) {
            fromToken.safeApprove(router, type(uint256).max);
        }

        // Always just send all the WNT to the withdrawal vault as everything will be refunded
        // It requires that there's enough gas to pay the keeper, but for atomic withdrawals,
        // the sender is the keeper. Excess amounts will also be refunded.
        // Can be calculated as follows:
        // uint256 estimatedGasLimit = dataStore.getUint(Keys.withdrawalGasLimitKey());
        // uint256 oraclePriceCount = 3;
        //
        // uint256 baseGasLimit = dataStore.getUint(Keys.ESTIMATED_GAS_FEE_BASE_AMOUNT_V2_1);
        // baseGasLimit += dataStore.getUint(Keys.ESTIMATED_GAS_FEE_PER_ORACLE_PRICE) * oraclePriceCount;
        // uint256 multiplierFactor = dataStore.getUint(Keys.ESTIMATED_GAS_FEE_MULTIPLIER_FACTOR);
        // uint256 gasLimit = baseGasLimit + Precision.applyFactor(estimatedGasLimit, multiplierFactor);
        // uint256 minExecutionFee = gasLimit * tx.gasprice;
        exchangeRouter.sendWnt{value: address(this).balance}(withdrawalVault, address(this).balance);
        exchangeRouter.sendTokens(fromToken, withdrawalVault, amount);
        exchangeRouter.executeAtomicWithdrawal(
            IExchangeRouter.CreateWithdrawalParams({
                receiver: address(this),
                callbackContract: address(0),
                uiFeeReceiver: address(0),
                market: fromToken,
                longTokenSwapPath: new address[](0),
                shortTokenSwapPath: new address[](0),
                // Mimimum amounts are enforced by shareToMin
                minLongTokenAmount: 1,
                minShortTokenAmount: 1,
                shouldUnwrapNativeToken: false,
                executionFee: address(this).balance,
                callbackGasLimit: 0
            }),
            setPricesParams
        );

        for (uint256 i = 0; i < swapData.length; ++i) {
            SwapData memory swapDatum = swapData[i];
            if (IERC20(swapDatum.token).allowance(address(this), swapDatum.to) != type(uint256).max) {
                swapDatum.token.safeApproveWithRetry(swapDatum.to, type(uint256).max);
            }
            swapDatum.to.functionCall(swapDatum.data);

            uint256 remainingBalance = swapDatum.token.balanceOf(address(this));
            if (remainingBalance > 0) {
                swapDatum.token.safeTransfer(recipient, remainingBalance);
            }
        }

        // Refund execution fee
        recipient.safeTransferAllETH();

        (, shareReturned) = box.deposit(mim, address(this), recipient, mim.balanceOf(address(this)), 0);
        extraShare = shareReturned - shareToMin;
    }

    receive() external payable {}
}
