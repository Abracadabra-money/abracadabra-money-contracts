// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {mulDiv} from "@prb/math/Common.sol";
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

interface IDataStore {
    function getUint(bytes32 key) external view returns (uint256);
}

library Keys {
    bytes32 public constant WITHDRAWAL_GAS_LIMIT = keccak256(abi.encode("WITHDRAWAL_GAS_LIMIT"));
    bytes32 public constant ESTIMATED_GAS_FEE_BASE_AMOUNT_V2_1 = keccak256(abi.encode("ESTIMATED_GAS_FEE_BASE_AMOUNT_V2_1"));
    bytes32 public constant ESTIMATED_GAS_FEE_PER_ORACLE_PRICE = keccak256(abi.encode("ESTIMATED_GAS_FEE_PER_ORACLE_PRICE"));
    bytes32 public constant ESTIMATED_GAS_FEE_MULTIPLIER_FACTOR = keccak256(abi.encode("ESTIMATED_GAS_FEE_MULTIPLIER_FACTOR"));
}

library Precision {
    uint256 public constant FLOAT_PRECISION = 10 ** 30;

    function applyFactor(uint256 value, uint256 factor) internal pure returns (uint256) {
        return mulDiv(value, factor, FLOAT_PRECISION);
    }
}

contract GMSwapper {
    using SafeTransferLib for address;
    using Address for address;

    IBentoBoxLite public immutable box;
    address public immutable mim;
    IExchangeRouter public immutable exchangeRouter;
    address public immutable router;
    address public immutable withdrawalVault;
    IDataStore public immutable dataStore;

    struct SwapData {
        address token;
        address to;
        bytes data;
    }

    error ErrSlippageExceeded(uint256 shareReturned);
    error ErrBadSwapTarget();
    error ErrBadOraclePriceCount();

    constructor(
        IBentoBoxLite _box,
        address _mim,
        IExchangeRouter _exchangeRouter,
        address _router,
        address _withdrawalVault,
        IDataStore _dataStore
    ) {
        box = _box;
        mim = _mim;
        exchangeRouter = _exchangeRouter;
        router = _router;
        withdrawalVault = _withdrawalVault;
        dataStore = _dataStore;

        _mim.safeApprove(address(_box), type(uint256).max);
    }

    /// @dev Ensure this function has sufficient native token balance to pay the execution fee.
    /// If used for liquidations, the execution fee must be sent atomically in same transaction
    /// to prevent others from withdrawing the fee. For deleverage just use value to pay the
    /// execution fee. Note that the execution fee will always be fully refunded to the recipient.
    /// This function is ONLY intended to be used as part of an atomic transaction! DO NOT send
    /// tokens directly to this contract! ALWAYS ensure that any token output is either native token,
    /// MIM or a left over balance from a swap (only applies to immediately after the swap). Any other
    /// token may be lost!
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
                executionFee: 0,
                callbackGasLimit: 0
            }),
            setPricesParams
        );

        for (uint256 i = 0; i < swapData.length; ++i) {
            SwapData memory swapDatum = swapData[i];

            // Do not allow calls to mim as it could modify the approval
            // set in the constructor.
            require(swapDatum.to != mim, ErrBadSwapTarget());

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
        require(shareReturned >= shareToMin, ErrSlippageExceeded(shareReturned));
        unchecked {
            extraShare = shareReturned - shareToMin;
        }
    }

    function getMinExecutionFee(uint256 oraclePriceCount, uint256 currentGasPrice) public view returns (uint256 minExecutionFee) {
        require(oraclePriceCount >= 3, ErrBadOraclePriceCount());
        uint256 estimatedGasLimit = dataStore.getUint(Keys.WITHDRAWAL_GAS_LIMIT);
        uint256 baseGasLimit = dataStore.getUint(Keys.ESTIMATED_GAS_FEE_BASE_AMOUNT_V2_1);
        baseGasLimit += dataStore.getUint(Keys.ESTIMATED_GAS_FEE_PER_ORACLE_PRICE) * oraclePriceCount;
        uint256 multiplierFactor = dataStore.getUint(Keys.ESTIMATED_GAS_FEE_MULTIPLIER_FACTOR);
        uint256 gasLimit = baseGasLimit + Precision.applyFactor(estimatedGasLimit, multiplierFactor);
        return gasLimit * currentGasPrice;
    }

    receive() external payable {}
}
