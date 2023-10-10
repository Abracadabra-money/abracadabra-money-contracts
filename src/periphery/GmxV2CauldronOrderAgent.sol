// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ICauldronV4} from "interfaces/ICauldronV4.sol";
import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {IGmxReader} from "interfaces/IGmxReader.sol";
import {OperatableV2} from "mixins/OperatableV2.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IDepositCallbackReceiver} from "interfaces/IDepositCallbackReceiver.sol";
import {IOracle} from "interfaces/IOracle.sol";
import {GmxV2Deposit, GmxV2EventUtils} from "libraries/GmxV2Libs.sol";
import {GmxV2Market} from "libraries/GmxV2Libs.sol";

/** @dev CreateDepositParams struct used in createDeposit to avoid stack
 * too deep errors
 *
 * @param receiver the address to send the market tokens to
 * @param callbackContract the callback contract
 * @param uiFeeReceiver the ui fee receiver
 * @param market the market to deposit into
 * @param minMarketTokens the minimum acceptable number of liquidity tokens
 * @param shouldUnwrapNativeToken whether to unwrap the native token when
 * sending funds back to the user in case the deposit gets cancelled
 * @param executionFee the execution fee for keepers
 * @param callbackGasLimit the gas limit for the callbackContract
 */
struct CreateDepositParams {
    address receiver;
    address callbackContract;
    address uiFeeReceiver;
    address market;
    address initialLongToken;
    address initialShortToken;
    address[] longTokenSwapPath;
    address[] shortTokenSwapPath;
    uint256 minMarketTokens;
    bool shouldUnwrapNativeToken;
    uint256 executionFee;
    uint256 callbackGasLimit;
}

/**
 * @param receiver The address that will receive the withdrawal tokens.
 * @param callbackContract The contract that will be called back.
 * @param market The market on which the withdrawal will be executed.
 * @param minLongTokenAmount The minimum amount of long tokens that must be withdrawn.
 * @param minShortTokenAmount The minimum amount of short tokens that must be withdrawn.
 * @param shouldUnwrapNativeToken Whether the native token should be unwrapped when executing the withdrawal.
 * @param executionFee The execution fee for the withdrawal.
 * @param callbackGasLimit The gas limit for calling the callback contract.
 */
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

struct GmRouterOrderParams {
    IOracle oracle;
    uint256 inputAmount;
    IERC20 inputToken;
    address market;
    uint256 executionFee;
    uint256 minOutput;
    bool deposit;
}

interface IGmCauldronOrderAgent {
    function createOrder(address user, GmRouterOrderParams memory params) external payable returns (address order);
}

interface IGmRouterOrder {
    function init(address _owner, address user, GmRouterOrderParams memory _params) external payable;

    /// @notice cancelling an order
    function cancelOrder() external;

    /// @notice withdraw from an order that does not end in addition of collateral.
    function withdrawFromOrder(address token, address to, uint256 amount) external;

    /// @notice the value of the order in collateral terms
    function orderValueInCollateral() external view returns (uint256);
}

interface IGmxV2DepositHandler {
    function depositVault() external view returns (address);

    function dataStore() external view returns (address);
}

interface IGmxV2WithdrawalHandler {
    function withdrawalVault() external view returns (address);
}

interface IGmxV2ExchangeRouter {
    function dataStore() external view returns (address);

    function sendWnt(address receiver, uint256 amount) external payable;

    function sendTokens(address token, address receiver, uint256 amount) external payable;

    function depositHandler() external view returns (address);

    function withdrawalHandler() external view returns (address);

    function createDeposit(CreateDepositParams calldata params) external payable returns (bytes32);

    function createWithdrawal(CreateWithdrawalParams calldata params) external payable returns (bytes32);

    function cancelDeposit(bytes32 key) external payable;
}

interface IGmxDataStore {
    function containsBytes32(bytes32 setKey, bytes32 value) external view returns (bool);
}

contract GmxV2CauldronRouterOrder is IGmRouterOrder, IDepositCallbackReceiver {
    using SafeTransferLib for address;

    error ErrFinalized();
    error ErrNotOnwer();
    error ErrAlreadyInitialized();

    bytes32 public constant DEPOSIT_LIST = keccak256(abi.encode("DEPOSIT_LIST"));
    bytes32 public constant WITHDRAWAL_LIST = keccak256(abi.encode("WITHDRAWAL_LIST"));
    uint256 public constant CALLBACK_GAS_LIMIT = 1_000_000;

    IGmxV2ExchangeRouter public immutable GMX_ROUTER;
    IGmxReader public immutable GMX_READER;
    IGmxDataStore public immutable DATASTORE;
    address public immutable DEPOSIT_VAULT;
    address public immutable WITHDRAWAL_VAULT;
    address public immutable SYNTHETICS_ROUTER;

    address public owner;
    address public user;
    bytes32 public orderKey;

    modifier onlyOwner() virtual {
        if (msg.sender != owner) {
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

    function init(address _owner, address _user, GmRouterOrderParams memory params) external payable {
        if (owner != address(0)) {
            revert ErrAlreadyInitialized();
        }

        owner = _owner;
        user = _user;

        address(params.inputToken).safeApprove(address(SYNTHETICS_ROUTER), params.inputAmount);
        GmxV2Market.Props memory props = GMX_READER.getMarket(address(DATASTORE), params.market);

        if (params.deposit) {
            orderKey = _createDepositOrder(
                params.market,
                address(params.inputToken),
                props.indexToken,
                params.inputAmount,
                params.minOutput,
                params.executionFee
            );
        } else {
            //orderKey = _createWithdrawalOrder();
        }
    }

    function cancelOrder() external {
        GMX_ROUTER.cancelDeposit(orderKey);
    }

    function withdrawFromOrder(address token, address to, uint256 amount) external {
        revert("Not Implemented");
    }

    /// @notice the value of the order in collateral terms
    function orderValueInCollateral() external view returns (uint256) {
        revert("Not Implemented");
        return 0;
    }

    function cancelDeposit(bytes32 key) external payable onlyOwner {
        revert("Not Implemented");
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

        CreateDepositParams memory params = CreateDepositParams({
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

    // @dev called after a deposit execution
    // @param key the key of the deposit
    // @param deposit the deposit that was executed
    function afterDepositExecution(
        bytes32 /*key*/,
        GmxV2Deposit.Props memory deposit,
        GmxV2EventUtils.EventLogData memory /*eventData*/
    ) external override {
        uint256 received = IERC20(deposit.addresses.market).balanceOf(address(this));
        deposit.addresses.market.safeTransfer(ICauldronV4(owner).bentoBox(), received);
        //ICauldronV4(owner).addCollateral();
        // ICauldron(owner).closeOrder();
    }

    // @dev called after a deposit cancellation
    // @param key the key of the deposit
    // @param deposit the deposit that was cancelled
    function afterDepositCancellation(
        bytes32 key,
        GmxV2Deposit.Props memory deposit,
        GmxV2EventUtils.EventLogData memory eventData
    ) external override {}
}

contract GmxV2CauldronOrderAgent is IGmCauldronOrderAgent {
    using SafeTransferLib for address;

    error ErrInvalidParams();

    address public immutable orderImplementation;

    mapping(address account => uint nonce) public nonces;

    constructor(address _orderImplementation) {
        orderImplementation = _orderImplementation;
    }

    function createOrder(address user, GmRouterOrderParams memory params) external payable override returns (address order) {
        nonces[msg.sender]++;

        (bytes32 salt, bytes memory data) = _getOrderDeterministicAddressParameters(msg.sender, nonces[msg.sender]);
        order = LibClone.cloneDeterministic(orderImplementation, data, salt);
        address(params.inputToken).safeTransfer(order, params.inputAmount);
        IGmRouterOrder(order).init{value: msg.value}(msg.sender, user, params);
    }

    function getOrderAddress(address _account, uint _nonce) public view returns (address) {
        (bytes32 salt, bytes memory data) = _getOrderDeterministicAddressParameters(_account, _nonce);
        return LibClone.predictDeterministicAddress(orderImplementation, data, salt, address(this));
    }

    function _getOrderDeterministicAddressParameters(address _account, uint _nonce) private view returns (bytes32 salt, bytes memory data) {
        salt = keccak256(abi.encodePacked(_account, _nonce));
        data = abi.encodePacked(orderImplementation);
    }
}
