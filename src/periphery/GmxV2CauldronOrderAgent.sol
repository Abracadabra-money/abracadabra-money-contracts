// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {ICauldronV4GmxV2, ICauldronV4} from "interfaces/ICauldronV4GmxV2.sol";
import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {OperatableV2} from "mixins/OperatableV2.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IOracle} from "interfaces/IOracle.sol";
import {IGmxV2Deposit, IGmxV2WithdrawalCallbackReceiver, IGmxV2Withdrawal, IGmxV2EventUtils, IGmxV2Market, IGmxDataStore, IGmxV2DepositCallbackReceiver, IGmxReader, IGmxV2DepositHandler, IGmxV2WithdrawalHandler, IGmxV2ExchangeRouter} from "interfaces/IGmxV2.sol";

struct GmRouterOrderParams {
    address inputToken;
    bool deposit;
    uint256 inputAmount;
    uint256 executionFee;
    uint256 minOutput;
}

interface IGmCauldronOrderAgent {
    function createOrder(address user, GmRouterOrderParams memory params) external payable returns (address order);
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
}

contract GmxV2CauldronRouterOrder is IGmRouterOrder, IGmxV2DepositCallbackReceiver, IGmxV2WithdrawalCallbackReceiver {
    using SafeTransferLib for address;

    error ErrFinalized();
    error ErrNotOnwer();
    error ErrAlreadyInitialized();

    uint256 internal constant EXCHANGE_RATE_PRECISION = 1e18;

    bytes32 public constant DEPOSIT_LIST = keccak256(abi.encode("DEPOSIT_LIST"));
    bytes32 public constant WITHDRAWAL_LIST = keccak256(abi.encode("WITHDRAWAL_LIST"));
    uint256 public constant CALLBACK_GAS_LIMIT = 1_000_000;

    IGmxV2ExchangeRouter public immutable GMX_ROUTER;
    IGmxReader public immutable GMX_READER;
    IGmxDataStore public immutable DATASTORE;
    address public immutable DEPOSIT_VAULT;
    address public immutable WITHDRAWAL_VAULT;
    address public immutable SYNTHETICS_ROUTER;

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

    constructor(IGmxV2ExchangeRouter _gmxRouter, address _syntheticsRouter, IGmxReader _gmxReader) {
        GMX_ROUTER = _gmxRouter;
        GMX_READER = _gmxReader;
        SYNTHETICS_ROUTER = _syntheticsRouter;
        DATASTORE = IGmxDataStore(_gmxRouter.dataStore());
        DEPOSIT_VAULT = IGmxV2DepositHandler(_gmxRouter.depositHandler()).depositVault();
        WITHDRAWAL_VAULT = IGmxV2WithdrawalHandler(_gmxRouter.withdrawalHandler()).withdrawalVault();
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
        token.safeTransfer(to, amount);
        if (closeOrder) {
            ICauldronV4GmxV2(cauldron).closeOrder(user);
        }
    }

    // TODO: question any case in which the state is that gm tokens are in the contract
    function sendValueInCollateral(address recipient, uint256 amount) public onlyCauldron {
        (uint256 shortExchangeRate, uint256 marketExchangeRate) = getExchangeRates();
        uint256 amountShortToken = (amount * EXCHANGE_RATE_PRECISION * EXCHANGE_RATE_PRECISION) / (shortExchangeRate * marketExchangeRate);
        shortToken.safeTransfer(recipient, amountShortToken);
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
            marketTokenAmount: _inputAmount,
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
        market.safeTransfer(ICauldronV4(cauldron).bentoBox(), received);
        (, uint256 share) = IBentoBoxV1(ICauldronV4(cauldron).bentoBox()).deposit(
            IERC20(market),
            address(ICauldronV4(cauldron).bentoBox()),
            cauldron,
            received,
            0
        );
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
    ) external override {
        _depositMarketTokensAsCollateral();
    }

    // @dev called after a deposit cancellation
    // @param key the key of the deposit
    // @param deposit the deposit that was cancelled
    function afterDepositCancellation(
        bytes32 key,
        IGmxV2Deposit.Props memory deposit,
        IGmxV2EventUtils.EventLogData memory eventData
    ) external override {
        // TODO: Validate that when a cancellation happen externally, the USDC tokens are sent back to the order.
    }

    // @dev called after a withdrawal execution
    // @param key the key of the withdrawal
    // @param withdrawal the withdrawal that was executed
    function afterWithdrawalExecution(
        bytes32 key,
        IGmxV2Withdrawal.Props memory withdrawal,
        IGmxV2EventUtils.EventLogData memory eventData
    ) external override {
        // TODO: use the usdc to swap back to MIM and deleverage
    }

    // @dev called after a withdrawal cancellation
    // @param key the key of the withdrawal
    // @param withdrawal the withdrawal that was cancelled
    function afterWithdrawalCancellation(
        bytes32 /*key*/,
        IGmxV2Withdrawal.Props memory /*withdrawal*/,
        IGmxV2EventUtils.EventLogData memory /*eventData*/
    ) external override {
        _depositMarketTokensAsCollateral();
    }
}

contract GmxV2CauldronOrderAgent is IGmCauldronOrderAgent, OperatableV2 {
    using SafeTransferLib for address;

    event LogSetOracle(address indexed market, IOracle indexed oracle);

    error ErrInvalidParams();

    address public immutable orderImplementation;
    IBentoBoxV1 public immutable degenBox;
    mapping(address => IOracle) public oracles;

    constructor(IBentoBoxV1 _degenBox, address _orderImplementation, address _owner) OperatableV2(_owner) {
        degenBox = _degenBox;
        orderImplementation = _orderImplementation;
    }

    function setOracle(address market, IOracle oracle) external onlyOwner {
        oracles[market] = oracle;
        emit LogSetOracle(market, oracle);
    }

    function createOrder(address user, GmRouterOrderParams memory params) external payable override returns (address order) {
        order = LibClone.clone(orderImplementation);
        degenBox.withdraw(IERC20(params.inputToken), address(this), address(order), params.inputAmount, 0);
        IGmRouterOrder(order).init{value: msg.value}(msg.sender, user, params);
    }
}