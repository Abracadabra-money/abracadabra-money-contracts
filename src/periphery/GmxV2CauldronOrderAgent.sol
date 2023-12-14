// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {ICauldronV4GmxV2} from "interfaces/ICauldronV4GmxV2.sol";
import {ICauldronV4} from "interfaces/ICauldronV4.sol";
import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {OperatableV2} from "mixins/OperatableV2.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IOracle} from "interfaces/IOracle.sol";
import {IGmxV2Deposit, IGmxV2WithdrawalCallbackReceiver, IGmxV2Withdrawal, IGmxV2EventUtils, IGmxV2Market, IGmxDataStore, IGmxV2DepositCallbackReceiver, IGmxReader, IGmxV2DepositHandler, IGmxV2WithdrawalHandler, IGmxV2ExchangeRouter} from "interfaces/IGmxV2.sol";
import {IWETH} from "interfaces/IWETH.sol";
import {BoringERC20} from "BoringSolidity/libraries/BoringERC20.sol";

struct GmRouterOrderParams {
    address inputToken;
    bool deposit;
    uint128 inputAmount;
    uint128 executionFee;
    uint128 minOutput;
    uint128 minOutLong; // 0 for deposit
}

interface IGmCauldronOrderAgent {
    function createOrder(address user, GmRouterOrderParams memory params) external payable returns (address order);

    function setOracle(address market, IOracle oracle) external;

    function oracles(address market) external view returns (IOracle);

    function callbackGasLimit() external view returns (uint256);

    function setCallbackGasLimit(uint256 _callbackGasLimit) external;
}

interface IGmRouterOrder {
    function init(address _cauldron, address user, GmRouterOrderParams memory _params) external payable;

    /// @notice cancelling an order
    function cancelOrder() external;

    function getExchangeRates() external view returns (uint256 shortExchangeRate, uint256 marketExchangeRate);

    /// @notice withdraw from an order that does not end in addition of collateral.
    function withdrawFromOrder(address token, address to, uint256 amount, bool closeOrder) external;

    /// @notice the value of the order in collateral terms
    function orderValueInCollateral() external view returns (uint256);

    /// @notice sends a specific value to recipient
    function sendValueInCollateral(address recipient, uint256 share) external;

    function isActive() external view returns (bool);

    function orderKey() external view returns (bytes32);

    function orderAgent() external view returns (IGmCauldronOrderAgent);
}

contract GmxV2CauldronRouterOrder is IGmRouterOrder, IGmxV2DepositCallbackReceiver, IGmxV2WithdrawalCallbackReceiver {
    using SafeTransferLib for address;
    using BoringERC20 for IERC20;

    error ErrFinalized();
    error ErrNotOwner();
    error ErrAlreadyInitialized();
    error ErrMinOutTooLarge();
    error ErrUnauthorized();
    error ErrWrongUser();
    error ErrIncorrectInitialization();
    error ErrExecuteDepositsDisabled();
    error ErrExecuteWithdrawalsDisabled();

    event LogRefundWETH(address indexed user, uint256 amount);

    bytes32 public constant DEPOSIT_LIST = keccak256(abi.encode("DEPOSIT_LIST"));
    bytes32 public constant WITHDRAWAL_LIST = keccak256(abi.encode("WITHDRAWAL_LIST"));
    bytes32 public constant ORDER_KEEPER = keccak256(abi.encode("ORDER_KEEPER"));
    bytes32 public constant EXECUTE_DEPOSIT_FEATURE_DISABLED = keccak256(abi.encode("EXECUTE_DEPOSIT_FEATURE_DISABLED"));
    bytes32 public constant EXECUTE_WITHDRAWAL_FEATURE_DISABLED = keccak256(abi.encode("EXECUTE_WITHDRAWAL_FEATURE_DISABLED"));

    IGmxV2ExchangeRouter public immutable GMX_ROUTER;
    IGmxReader public immutable GMX_READER;
    IGmxDataStore public immutable DATASTORE;
    address public immutable DEPOSIT_VAULT;
    address public immutable WITHDRAWAL_VAULT;
    address public immutable SYNTHETICS_ROUTER;
    IWETH public immutable WETH;
    address public immutable REFUND_TO;
    IBentoBoxV1 public immutable degenBox;

    address public cauldron;
    address public user;
    bytes32 public orderKey;
    address public market;
    address public shortToken;
    IOracle public oracle;
    uint128 public inputAmount;
    uint128 public minOut;
    uint128 public minOutLong;
    uint128 public oracleDecimalScale;

    bool public depositType;
    bool public isHomogenousMarket;
    IGmCauldronOrderAgent public orderAgent;

    modifier onlyCauldron() virtual {
        if (msg.sender != cauldron) {
            revert ErrNotOwner();
        }
        _;
    }

    modifier onlyDepositHandler() {
        if (msg.sender != address(GMX_ROUTER.depositHandler())) {
            revert ErrUnauthorized();
        }
        _;
    }

    modifier onlyWithdrawalHandler() {
        if (msg.sender != address(GMX_ROUTER.withdrawalHandler())) {
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
        IBentoBoxV1 _degenBox,
        IGmxV2ExchangeRouter _gmxRouter,
        address _syntheticsRouter,
        IGmxReader _gmxReader,
        IWETH _weth,
        address _refundTo
    ) {
        degenBox = _degenBox;
        GMX_ROUTER = _gmxRouter;
        GMX_READER = _gmxReader;
        SYNTHETICS_ROUTER = _syntheticsRouter;
        DATASTORE = IGmxDataStore(_gmxRouter.dataStore());
        DEPOSIT_VAULT = IGmxV2DepositHandler(_gmxRouter.depositHandler()).depositVault();
        WITHDRAWAL_VAULT = IGmxV2WithdrawalHandler(_gmxRouter.withdrawalHandler()).withdrawalVault();
        WETH = _weth;
        REFUND_TO = _refundTo;
    }

    function init(address _cauldron, address _user, GmRouterOrderParams memory params) external payable {
        if (cauldron != address(0)) {
            revert ErrAlreadyInitialized();
        }

        if (_cauldron == address(0)) {
            revert ErrIncorrectInitialization();
        }

        orderAgent = GmxV2CauldronOrderAgent(msg.sender);
        cauldron = _cauldron;
        user = _user;

        market = address(ICauldronV4(_cauldron).collateral());
        IGmxV2Market.Props memory props = GMX_READER.getMarket(address(DATASTORE), market);

        inputAmount = params.inputAmount;
        minOut = params.minOutput;
        minOutLong = params.minOutLong;

        if (uint256(params.minOutput) + uint256(params.minOutLong) > type(uint128).max) {
            revert ErrMinOutTooLarge();
        }

        isHomogenousMarket = props.longToken == props.shortToken;
        shortToken = props.shortToken;
        depositType = params.deposit;

        oracleDecimalScale = uint128(10 ** (orderAgent.oracles(shortToken).decimals() + IERC20(shortToken).safeDecimals()));

        if (depositType) {
            if (isDepositExecutionDisabled()) {
                revert ErrExecuteDepositsDisabled();
            }

            shortToken.safeApprove(address(SYNTHETICS_ROUTER), params.inputAmount);
            orderKey = _createDepositOrder(
                market,
                props.shortToken,
                props.longToken,
                params.inputAmount,
                params.minOutput,
                params.executionFee
            );
        } else {
            if (isWithdrawalExecutionDisabled()) {
                revert ErrExecuteWithdrawalsDisabled();
            }
            
            market.safeApprove(address(SYNTHETICS_ROUTER), params.inputAmount);
            orderKey = _createWithdrawalOrder(params.inputAmount, params.minOutput, params.minOutLong, params.executionFee);
        }
    }

    function isDepositExecutionDisabled() public view returns (bool) {
        bytes32 depositExecutionDisabledKey = keccak256(abi.encode(EXECUTE_DEPOSIT_FEATURE_DISABLED, GMX_ROUTER.depositHandler()));
        return DATASTORE.getBool(depositExecutionDisabledKey);
    }

    function isWithdrawalExecutionDisabled() public view returns (bool) {
        bytes32 withdrawalExecutionDisabledKey = keccak256(abi.encode(EXECUTE_WITHDRAWAL_FEATURE_DISABLED, GMX_ROUTER.withdrawalHandler()));
        return DATASTORE.getBool(withdrawalExecutionDisabledKey);
    }

    function cancelOrder() external onlyCauldron {
        if (depositType) {
            GMX_ROUTER.cancelDeposit(orderKey);
        } else {
            GMX_ROUTER.cancelWithdrawal(orderKey);
        }
    }

    function withdrawFromOrder(address token, address to, uint256 amount, bool) external onlyCauldron {
        token.safeTransfer(address(degenBox), amount);
        degenBox.deposit(IERC20(token), address(degenBox), to, amount, 0);

        uint256 balance = shortToken.balanceOf(address(this));
        if (balance > 0) {
            shortToken.safeTransfer(address(degenBox), balance);
            degenBox.deposit(IERC20(shortToken), address(degenBox), user, balance, 0);
        }
        ICauldronV4GmxV2(cauldron).closeOrder(user);
    }

    function sendValueInCollateral(address recipient, uint256 shareMarketToken) public onlyCauldron {
        (uint256 shortExchangeRate, uint256 marketExchangeRate) = getExchangeRates();

        /// @dev For oracleDecimalScale = 1e14:
        /// (18 decimals + 14 decimals) - (8 decimals + 18 decimals) = 6 decimals
        ///
        /// Ex:
        /// - 100,000 GM token where 1 GM = 0.5 USD each
        /// - 1 USDC = 0.997 USD
        /// - 99700000 is the chainlink oracle USDC price in USD with 8 decimals
        /// - 2e18 is how many GM tokens 1 USD can buy
        /// - 1e14 is 8 decimals for the chainlink oracle + 6 decimals for USDC
        /// (100_000e18 * 1e14) / (99700000 *  2e18) = ≈50150.45e6 USDC
        uint256 amountShortToken = (degenBox.toAmount(IERC20(market), shareMarketToken, true) * oracleDecimalScale) /
            (shortExchangeRate * marketExchangeRate);

        shortToken.safeTransfer(address(degenBox), amountShortToken);
        degenBox.deposit(IERC20(shortToken), address(degenBox), recipient, amountShortToken, 0);
    }

    /// @notice the value of the order in collateral terms
    function orderValueInCollateral() public view returns (uint256 result) {
        (uint256 shortExchangeRate, uint256 marketExchangeRate) = getExchangeRates();

        /// @dev short exchangeRate is in USD in native decimals
        /// marketExchangeRate is in inverse similar to other cauldron oracles 1e36 / (price in 18 decimals)
        /// Ex:
        /// - input is 100,000 USDC
        /// - 1 USDC = 0.997 USD
        /// - 99700000 is the chainlink oracle USDC price in USD with 8 decimals
        /// - 2e18 is how many GM tokens 1 USD can buy
        ///  (100_000e6 * 99700000 * 2e18) / 1e14 = ≈199400e18 GM tokens
        if (depositType) {
            uint256 marketTokenFromValue = (inputAmount * shortExchangeRate * marketExchangeRate) / oracleDecimalScale;
            result = minOut < marketTokenFromValue ? minOut : marketTokenFromValue;
        } else {
            uint256 marketTokenFromValue = ((minOut + minOutLong) * shortExchangeRate * marketExchangeRate) / oracleDecimalScale;
            result = inputAmount < marketTokenFromValue ? inputAmount : marketTokenFromValue;
        }
    }

    function getExchangeRates() public view returns (uint256 shortExchangeRate, uint256 marketExchangeRate) {
        (, shortExchangeRate) = orderAgent.oracles(shortToken).peek(bytes(""));
        (, marketExchangeRate) = orderAgent.oracles(market).peek(bytes(""));
    }

    function isActive() public view returns (bool) {
        return DATASTORE.containsBytes32(DEPOSIT_LIST, orderKey) || DATASTORE.containsBytes32(WITHDRAWAL_LIST, orderKey);
    }

    function _createDepositOrder(
        address _gmToken,
        address _inputToken,
        address _underlyingToken,
        uint128 _usdcAmount,
        uint128 _minGmTokenOutput,
        uint128 _executionFee
    ) private returns (bytes32) {
        GMX_ROUTER.sendWnt{value: _executionFee}(address(DEPOSIT_VAULT), _executionFee);
        GMX_ROUTER.sendTokens(_inputToken, address(DEPOSIT_VAULT), _usdcAmount);

        address[] memory emptyPath = new address[](0);

        IGmxV2Deposit.CreateDepositParams memory params = IGmxV2Deposit.CreateDepositParams({
            receiver: address(this),
            callbackContract: address(this),
            uiFeeReceiver: address(0),
            market: _gmToken,
            initialLongToken: _underlyingToken,
            initialShortToken: _inputToken,
            longTokenSwapPath: emptyPath,
            shortTokenSwapPath: emptyPath,
            minMarketTokens: _minGmTokenOutput,
            shouldUnwrapNativeToken: false,
            executionFee: _executionFee,
            callbackGasLimit: orderAgent.callbackGasLimit()
        });

        return GMX_ROUTER.createDeposit(params);
    }

    function _createWithdrawalOrder(
        uint128 _inputAmount,
        uint128 _minUsdcOutput,
        uint128 _minOutLong,
        uint128 _executionFee
    ) private returns (bytes32) {
        GMX_ROUTER.sendWnt{value: _executionFee}(address(WITHDRAWAL_VAULT), _executionFee);
        GMX_ROUTER.sendTokens(market, address(WITHDRAWAL_VAULT), _inputAmount);

        address[] memory path = new address[](1);
        path[0] = market;

        address[] memory emptyPath = new address[](0);

        IGmxV2Withdrawal.CreateWithdrawalParams memory params = IGmxV2Withdrawal.CreateWithdrawalParams({
            receiver: address(this),
            callbackContract: address(this),
            uiFeeReceiver: address(0),
            market: market,
            longTokenSwapPath: isHomogenousMarket ? emptyPath : path,
            shortTokenSwapPath: emptyPath,
            minLongTokenAmount: _minOutLong,
            minShortTokenAmount: _minUsdcOutput,
            shouldUnwrapNativeToken: false,
            executionFee: _executionFee,
            callbackGasLimit: orderAgent.callbackGasLimit()
        });

        return GMX_ROUTER.createWithdrawal(params);
    }

    function _depositMarketTokensAsCollateral() internal {
        uint256 received = IERC20(market).balanceOf(address(this));
        market.safeTransfer(address(degenBox), received);
        (, uint256 share) = degenBox.deposit(IERC20(market), address(degenBox), cauldron, received, 0);
        ICauldronV4(cauldron).addCollateral(user, true, share);
        ICauldronV4GmxV2(cauldron).closeOrder(user);
    }

    function afterDepositExecution(
        bytes32 /*key*/,
        IGmxV2Deposit.Props memory deposit,
        IGmxV2EventUtils.EventLogData memory /*eventData*/
    ) external override onlyDepositHandler {
        // verify that the deposit was from this address
        if (deposit.addresses.account != address(this)) {
            revert ErrWrongUser();
        }
        _depositMarketTokensAsCollateral();
    }

    function afterWithdrawalCancellation(
        bytes32 /*key*/,
        IGmxV2Withdrawal.Props memory withdrawal,
        IGmxV2EventUtils.EventLogData memory /*eventData*/
    ) external override onlyWithdrawalHandler {
        // verify that the withdrawal was from this address
        if (withdrawal.addresses.account != address(this)) {
            revert ErrWrongUser();
        }
        _depositMarketTokensAsCollateral();
    }

    function afterDepositCancellation(
        bytes32 key,
        IGmxV2Deposit.Props memory deposit,
        IGmxV2EventUtils.EventLogData memory eventData
    ) external override {}

    function afterWithdrawalExecution(
        bytes32 key,
        IGmxV2Withdrawal.Props memory withdrawal,
        IGmxV2EventUtils.EventLogData memory eventData
    ) external override {}
}

contract GmxV2CauldronOrderAgent is IGmCauldronOrderAgent, OperatableV2 {
    using SafeTransferLib for address;

    event LogSetOracle(address indexed market, IOracle indexed oracle);
    event LogOrderCreated(address indexed order, address indexed user, GmRouterOrderParams params);
    event LogCallbackGasLimit(uint256 previous, uint256 current);

    error ErrInvalidParams();

    address public immutable orderImplementation;
    IBentoBoxV1 public immutable degenBox;
    mapping(address => IOracle) public oracles;

    uint256 public callbackGasLimit = 1_000_000;

    constructor(IBentoBoxV1 _degenBox, address _orderImplementation, address _owner) OperatableV2(_owner) {
        degenBox = _degenBox;
        orderImplementation = _orderImplementation;
    }

    function setCallbackGasLimit(uint256 _callbackGasLimit) external onlyOwner {
        emit LogCallbackGasLimit(callbackGasLimit, _callbackGasLimit);
        callbackGasLimit = _callbackGasLimit;
    }

    function setOracle(address market, IOracle oracle) external onlyOwner {
        oracles[market] = oracle;
        emit LogSetOracle(market, oracle);
    }

    function createOrder(address user, GmRouterOrderParams memory params) external payable override onlyOperators returns (address order) {
        order = LibClone.clone(orderImplementation);
        degenBox.withdraw(IERC20(params.inputToken), address(this), address(order), params.inputAmount, 0);
        IGmRouterOrder(order).init{value: msg.value}(msg.sender, user, params);

        emit LogOrderCreated(order, user, params);
    }
}
