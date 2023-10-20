// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {ICauldronV4GmxV2} from "interfaces/ICauldronV4GmxV2.sol";
import {ICauldronV4} from "interfaces/ICauldronV4.sol";
import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {OperatableV2} from "mixins/OperatableV2.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IOracle} from "interfaces/IOracle.sol";
import {IGmxV2Deposit, IGmxV2WithdrawalCallbackReceiver, IGmxV2Withdrawal, IGmxV2EventUtils, IGmxV2Market, IGmxDataStore, IGmxRoleStore, IGmxV2DepositCallbackReceiver, IGmxReader, IGmxV2DepositHandler, IGmxV2WithdrawalHandler, IGmxV2ExchangeRouter} from "interfaces/IGmxV2.sol";
import {IWETH} from "interfaces/IWETH.sol";

struct GmRouterOrderParams {
    address inputToken;
    bool deposit;
    uint256 inputAmount;
    uint256 executionFee;
    uint256 minOutput;
}

interface IGmCauldronOrderAgent {
    function createOrder(address user, GmRouterOrderParams memory params) external payable returns (address order);

    function setOracle(address market, IOracle oracle) external;
}

interface IGmRouterOrder {
    function init(address _cauldron, address user, GmRouterOrderParams memory _params) external payable;

    /// @notice cancelling an order
    function cancelOrder() external;

    /// @notice withdraw from an order that does not end in addition of collateral.
    function withdrawFromOrder(address token, address to, uint256 amount, bool closeOrder) external;

    /// @notice the value of the order in collateral terms
    function orderValueInCollateral() external view returns (uint256);

    /// @notice sends a specific value to recipient
    function sendValueInCollateral(address recipient, uint256 amount) external;

    function isActive() external view returns (bool);

    function orderKey() external view returns (bytes32);

    function refundWETH() external;
}

contract GmxV2CauldronRouterOrder is IGmRouterOrder, IGmxV2DepositCallbackReceiver, IGmxV2WithdrawalCallbackReceiver {
    using SafeTransferLib for address;

    error ErrFinalized();
    error ErrNotOnwer();
    error ErrAlreadyInitialized();
    error ErrMinOutTooLarge();
    error ErrUnauthorized();

    event LogRefundWETH(address indexed user, uint256 amount);

    uint256 internal constant EXCHANGE_RATE_PRECISION = 1e18;

    bytes32 public constant DEPOSIT_LIST = keccak256(abi.encode("DEPOSIT_LIST"));
    bytes32 public constant WITHDRAWAL_LIST = keccak256(abi.encode("WITHDRAWAL_LIST"));
    bytes32 public constant ORDER_KEEPER = keccak256(abi.encode("ORDER_KEEPER"));

    uint256 public constant CALLBACK_GAS_LIMIT = 1_000_000;

    IGmxV2ExchangeRouter public immutable GMX_ROUTER;
    IGmxReader public immutable GMX_READER;
    IGmxDataStore public immutable DATASTORE;
    IGmxRoleStore public immutable ROLESTORE;
    address public immutable DEPOSIT_VAULT;
    address public immutable WITHDRAWAL_VAULT;
    address public immutable SYNTHETICS_ROUTER;
    IWETH public immutable WETH;
    IBentoBoxV1 public immutable degenBox;

    address public cauldron;
    address public user;
    bytes32 public orderKey;
    address public market;
    address public shortToken;
    IOracle public oracle;
    uint256 public inputAmount;
    uint256 public minOut;
    bool public depositType;
    GmxV2CauldronOrderAgent public orderAgent;

    modifier onlyCauldron() virtual {
        if (msg.sender != cauldron) {
            revert ErrNotOnwer();
        }
        _;
    }

    modifier onlyOrderKeeper() {
        if (!ROLESTORE.hasRole(msg.sender, ORDER_KEEPER)) {
            revert ErrUnauthorized();
        }
        _;
    }

    constructor(IBentoBoxV1 _degenBox, IGmxV2ExchangeRouter _gmxRouter, address _syntheticsRouter, IGmxReader _gmxReader, IWETH _weth) {
        degenBox = _degenBox;
        GMX_ROUTER = _gmxRouter;
        GMX_READER = _gmxReader;
        SYNTHETICS_ROUTER = _syntheticsRouter;
        DATASTORE = IGmxDataStore(_gmxRouter.dataStore());
        ROLESTORE = IGmxRoleStore(DATASTORE.roleStore());
        DEPOSIT_VAULT = IGmxV2DepositHandler(_gmxRouter.depositHandler()).depositVault();
        WITHDRAWAL_VAULT = IGmxV2WithdrawalHandler(_gmxRouter.withdrawalHandler()).withdrawalVault();
        WETH = _weth;
    }

    function init(address _cauldron, address _user, GmRouterOrderParams memory params) external payable {
        if (cauldron != address(0)) {
            revert ErrAlreadyInitialized();
        }

        orderAgent = GmxV2CauldronOrderAgent(msg.sender);

        cauldron = _cauldron;
        user = _user;

        market = address(ICauldronV4(_cauldron).collateral());
        IGmxV2Market.Props memory props = GMX_READER.getMarket(address(DATASTORE), market);

        inputAmount = params.inputAmount;
        minOut = params.minOutput;

        if (minOut > type(uint128).max) {
            revert ErrMinOutTooLarge();
        }

        shortToken = props.shortToken;
        depositType = params.deposit;

        if (depositType) {
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
            market.safeApprove(address(SYNTHETICS_ROUTER), params.inputAmount);
            orderKey = _createWithdrawalOrder(params.inputAmount, params.minOutput, params.executionFee);
        }
    }

    function cancelOrder() external onlyCauldron {
        if (depositType) {
            GMX_ROUTER.cancelDeposit(orderKey);
        } else {
            GMX_ROUTER.cancelWithdrawal(orderKey);
        }
    }

    function withdrawFromOrder(address token, address to, uint256 amount, bool closeOrder) external onlyCauldron {
        token.safeTransfer(address(degenBox), amount);
        degenBox.deposit(IERC20(token), address(degenBox), to, amount, 0);

        if (closeOrder) {
            ICauldronV4GmxV2(cauldron).closeOrder(user);
        }
    }

    function sendValueInCollateral(address recipient, uint256 amount) public onlyCauldron {
        (uint256 shortExchangeRate, uint256 marketExchangeRate) = getExchangeRates();
        uint256 amountShortToken = (amount * EXCHANGE_RATE_PRECISION * EXCHANGE_RATE_PRECISION) / (shortExchangeRate * marketExchangeRate);

        shortToken.safeTransfer(address(degenBox), amountShortToken);
        degenBox.deposit(IERC20(shortToken), address(degenBox), recipient, amount, 0);
    }

    /// @notice the value of the order in collateral terms
    function orderValueInCollateral() public view returns (uint256 result) {
        (uint256 shortExchangeRate, uint256 marketExchangeRate) = getExchangeRates();

        if (depositType) {
            uint256 marketTokenFromValue = (inputAmount * shortExchangeRate * marketExchangeRate) /
                (EXCHANGE_RATE_PRECISION * EXCHANGE_RATE_PRECISION);
            result = minOut < marketTokenFromValue ? minOut : marketTokenFromValue;
        } else {
            uint256 marketTokenFromValue = (minOut * shortExchangeRate * marketExchangeRate) /
                (EXCHANGE_RATE_PRECISION * EXCHANGE_RATE_PRECISION);
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
        uint256 _usdcAmount,
        uint256 _minGmTokenOutput,
        uint256 _executionFee
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
            callbackGasLimit: CALLBACK_GAS_LIMIT
        });

        return GMX_ROUTER.createDeposit(params);
    }

    function _createWithdrawalOrder(uint256 _inputAmount, uint256 _minUsdcOutput, uint256 _executionFee) private returns (bytes32) {
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
            longTokenSwapPath: path,
            shortTokenSwapPath: emptyPath,
            minLongTokenAmount: 0,
            minShortTokenAmount: _minUsdcOutput,
            shouldUnwrapNativeToken: false,
            executionFee: _executionFee,
            callbackGasLimit: CALLBACK_GAS_LIMIT
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

    // @dev called after a deposit execution
    // @param key the key of the deposit
    // @param deposit the deposit that was executed
    function afterDepositExecution(
        bytes32 /*key*/,
        IGmxV2Deposit.Props memory /*deposit*/,
        IGmxV2EventUtils.EventLogData memory /*eventData*/
    ) external override onlyOrderKeeper {
        _depositMarketTokensAsCollateral();
    }

    // @dev called after a deposit cancellation
    // @param key the key of the deposit
    // @param deposit the deposit that was cancelled
    function afterDepositCancellation(
        bytes32 key,
        IGmxV2Deposit.Props memory deposit,
        IGmxV2EventUtils.EventLogData memory eventData
    ) external override {}

    // @dev called after a withdrawal execution
    // @param key the key of the withdrawal
    // @param withdrawal the withdrawal that was executed
    function afterWithdrawalExecution(
        bytes32 key,
        IGmxV2Withdrawal.Props memory withdrawal,
        IGmxV2EventUtils.EventLogData memory eventData
    ) external override {}

    // @dev called after a withdrawal cancellation
    // @param key the key of the withdrawal
    // @param withdrawal the withdrawal that was cancelled
    function afterWithdrawalCancellation(
        bytes32 /*key*/,
        IGmxV2Withdrawal.Props memory /*withdrawal*/,
        IGmxV2EventUtils.EventLogData memory /*eventData*/
    ) external override onlyOrderKeeper {
        _depositMarketTokensAsCollateral();
    }

    function refundWETH() public {
        emit LogRefundWETH(user, address(WETH).safeTransferAll(user));
    }
}

contract GmxV2CauldronOrderAgent is IGmCauldronOrderAgent, OperatableV2 {
    using SafeTransferLib for address;

    event LogSetOracle(address indexed market, IOracle indexed oracle);

    error ErrInvalidParams();
    error ErrWrongOracleDecimals();

    address public immutable orderImplementation;
    IBentoBoxV1 public immutable degenBox;
    mapping(address => IOracle) public oracles;

    constructor(IBentoBoxV1 _degenBox, address _orderImplementation, address _owner) OperatableV2(_owner) {
        degenBox = _degenBox;
        orderImplementation = _orderImplementation;
    }

    function setOracle(address market, IOracle oracle) external onlyOwner {
        if (oracle.decimals() != 18) {
            revert ErrWrongOracleDecimals();
        }

        oracles[market] = oracle;
        emit LogSetOracle(market, oracle);
    }

    function createOrder(address user, GmRouterOrderParams memory params) external payable override onlyOperators returns (address order) {
        order = LibClone.clone(orderImplementation);
        degenBox.withdraw(IERC20(params.inputToken), address(this), address(order), params.inputAmount, 0);
        IGmRouterOrder(order).init{value: msg.value}(msg.sender, user, params);
    }
}
