// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Address} from "openzeppelin-contracts/utils/Address.sol";
import {BaseStrategy} from "./BaseStrategy.sol";
import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {FeeCollectable} from "mixins/FeeCollectable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IGmxV2Deposit, IGmxV2ExchangeRouter, IGmxReader, IGmxV2EventUtils, IGmxDataStore, IGmxV2DepositHandler, IGmxV2DepositCallbackReceiver, IGmxV2Market} from "interfaces/IGmxV2.sol";
import {IMultiRewardsStaking} from "interfaces/IMultiRewardsStaking.sol";

contract GmStrategy is BaseStrategy, FeeCollectable, IGmxV2DepositCallbackReceiver {
    using SafeTransferLib for address;

    error ErrInsufficientAmountOut();
    error ErrExecuteDepositsDisabled();
    error ErrWrongUser();
    error ErrUnauthorized();
    error ErrInvalidToken();

    event LogCallbackGasLimitChanged(uint256 previous, uint256 current);
    event LogExchangeChanged(address indexed previous, address indexed current);
    event LogMarketMinted(uint256 total, uint256 strategyAmount, uint256 feeAmount);

    bytes32 public constant EXECUTE_DEPOSIT_FEATURE_DISABLED = keccak256(abi.encode("EXECUTE_DEPOSIT_FEATURE_DISABLED"));

    IGmxV2ExchangeRouter public immutable GMX_ROUTER;
    IGmxReader public immutable GMX_READER;
    IGmxDataStore public immutable DATASTORE;
    address public immutable DEPOSIT_VAULT;
    address public immutable SYNTHETICS_ROUTER;
    address public immutable REFUND_TO;
    address public immutable LONG_TOKEN;
    address public immutable SHORT_TOKEN;
    IMultiRewardsStaking public immutable STAKING;

    address public exchange;
    uint256 public callbackGasLimit = 2_000_000;
    bytes32 public orderKey;

    /// @dev Keep in memory the max balance once the GMX tokens are deposited
    uint256 private maxBalance;

    modifier onlyDepositHandler() {
        if (msg.sender != address(GMX_ROUTER.depositHandler())) {
            revert ErrUnauthorized();
        }
        _;
    }

    receive() external payable virtual {
        (bool success, ) = REFUND_TO.call{value: msg.value}("");

        // ignore failures
        if (!success) {
            return;
        }
    }

    constructor(
        address _strategyToken,
        IBentoBoxV1 _degenBox,
        IGmxV2ExchangeRouter _gmxRouter,
        IGmxReader _gmxReader,
        address _syntheticsRouter,
        address _refundTo,
        address _staking
    ) BaseStrategy(IERC20(_strategyToken), _degenBox) {
        assert(IMultiRewardsStaking(_staking).stakingToken() == _strategyToken);

        feeBips = 200; // 2%
        feeCollector = msg.sender;

        GMX_ROUTER = _gmxRouter;
        GMX_READER = _gmxReader;
        SYNTHETICS_ROUTER = _syntheticsRouter;
        DATASTORE = IGmxDataStore(_gmxRouter.dataStore());
        DEPOSIT_VAULT = IGmxV2DepositHandler(_gmxRouter.depositHandler()).depositVault();
        REFUND_TO = _refundTo;

        IGmxV2Market.Props memory props = GMX_READER.getMarket(address(DATASTORE), _strategyToken);
        LONG_TOKEN = props.longToken;
        SHORT_TOKEN = props.shortToken;

        STAKING = IMultiRewardsStaking(_staking);

        _strategyToken.safeApprove(address(_staking), type(uint256).max);
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// EXECUTORS
    //////////////////////////////////////////////////////////////////////////////////////////////

    /// @param _rewardToken Reward token from the staking contract
    /// @param _marketInputToken Same as _rewardToken when _swapData is empty,
    /// otherwise the token to use as market token input
    function run(
        address _rewardToken,
        address _marketInputToken,
        uint256 _marketMinOut,
        uint256 _executionFee,
        bytes memory _swapData,
        uint256 _maxBentoBoxAmountIncreaseInBips,
        uint256 _maxBentoBoxChangeAmountInBips
    ) external payable onlyExecutor {
        uint128 totals = bentoBox.totals(strategyToken).elastic;
        maxBalance = totals + ((totals * BIPS) / _maxBentoBoxAmountIncreaseInBips);
        uint256 maxChangeAmount = (maxBalance * _maxBentoBoxChangeAmountInBips) / BIPS;

        _safeHarvest(maxBalance, true, maxChangeAmount, false);
        _mintMarketTokens(_rewardToken, _marketInputToken, _marketMinOut, _executionFee, _swapData);
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// GMX CALLBACKS
    //////////////////////////////////////////////////////////////////////////////////////////////
    function afterDepositExecution(bytes32, IGmxV2Deposit.Props memory deposit, IGmxV2EventUtils.EventLogData memory) external override {
        // verify that the deposit was from this address
        if (deposit.addresses.account != address(this)) {
            revert ErrWrongUser();
        }

        uint256 total = strategyToken.balanceOf(address(this));
        (uint256 amountOut, uint256 feeAmount) = calculateFees(total);

        address(strategyToken).safeTransfer(feeCollector, feeAmount);
        emit LogMarketMinted(total, amountOut, feeAmount);

        _safeHarvest(maxBalance, true, 0, false);
    }

    function afterDepositCancellation(
        bytes32 key,
        IGmxV2Deposit.Props memory deposit,
        IGmxV2EventUtils.EventLogData memory eventData
    ) external override {}

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// ADMIN
    //////////////////////////////////////////////////////////////////////////////////////////////
    function cancelOrder() external onlyOwner {
        GMX_ROUTER.cancelDeposit(orderKey);
    }

    function setTokenApproval(address _token, address _to, uint256 _amount) external onlyOwner {
        _token.safeApprove(_to, _amount);
    }

    function setCallbackGasLimit(uint256 _callbackGasLimit) external onlyOwner {
        emit LogCallbackGasLimitChanged(callbackGasLimit, _callbackGasLimit);
        callbackGasLimit = _callbackGasLimit;
    }

    function setExchange(address _exchange) external onlyOwner {
        emit LogExchangeChanged(exchange, _exchange);
        exchange = _exchange;
    }

    function rescueToken(address _token, uint256 _amount, address _to) external onlyOwner {
        if (_token == address(strategyToken)) {
            revert ErrInvalidToken();
        }

        _token.safeTransfer(_to, _amount);
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// VIEWS
    //////////////////////////////////////////////////////////////////////////////////////////////
    function isFeeOperator(address account) public view override returns (bool) {
        return account == owner;
    }

    function isDepositExecutionDisabled() public view returns (bool) {
        bytes32 depositExecutionDisabledKey = keccak256(abi.encode(EXECUTE_DEPOSIT_FEATURE_DISABLED, GMX_ROUTER.depositHandler()));
        return DATASTORE.getBool(depositExecutionDisabledKey);
    }

    //////////////////////////////////////////////////////////////////////////////////////////////
    /// INTERNALS
    //////////////////////////////////////////////////////////////////////////////////////////////
    function _mintMarketTokens(
        address _rewardToken,
        address _marketInputToken,
        uint256 _marketMinOut,
        uint256 _executionFee,
        bytes memory _swapData
    ) internal {
        if (isDepositExecutionDisabled()) {
            revert ErrExecuteDepositsDisabled();
        }

        // only allow rize staking rewards
        if (!STAKING.isSupportedReward(_rewardToken)) {
            revert ErrInvalidToken();
        }
    
        if (_swapData.length > 0) {
            Address.functionCall(exchange, _swapData);
        }

        GMX_ROUTER.sendWnt{value: _executionFee}(address(DEPOSIT_VAULT), _executionFee);
        GMX_ROUTER.sendTokens(_marketInputToken, address(DEPOSIT_VAULT), _marketInputToken.balanceOf(address(this)));

        address[] memory emptyPath = new address[](0);

        IGmxV2Deposit.CreateDepositParams memory params = IGmxV2Deposit.CreateDepositParams({
            receiver: address(this),
            callbackContract: address(this),
            uiFeeReceiver: address(0),
            market: address(strategyToken),
            initialLongToken: LONG_TOKEN,
            initialShortToken: SHORT_TOKEN,
            longTokenSwapPath: emptyPath,
            shortTokenSwapPath: emptyPath,
            minMarketTokens: _marketMinOut,
            shouldUnwrapNativeToken: false,
            executionFee: _executionFee,
            callbackGasLimit: callbackGasLimit
        });

        orderKey = GMX_ROUTER.createDeposit(params);
    }

    function _skim(uint256 amount) internal override {
        STAKING.stake(amount);
        STAKING.getRewards();
    }

    function _harvest(uint256) internal override returns (int256) {
        STAKING.getRewards();
        return int256(0);
    }

    function _withdraw(uint256 amount) internal override {
        STAKING.withdraw(amount);
        STAKING.getRewards();
    }

    function _exit() internal override {
        STAKING.exit();
    }
}
