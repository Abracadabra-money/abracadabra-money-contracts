// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {OperatableV2} from "mixins/OperatableV2.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import "forge-std/console2.sol";

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

interface IMagicGmRouterOrder {
    function claim() external;

    function init(address _owner) external payable;

    function tokenIn() external view returns (IERC20);
}

interface IMagicGm {}

interface IGmxV2DepositHandler {
    function depositVault() external view returns (address);

    function dataStore() external view returns (address);
}

interface IGmxV2ExchangeRouter {
    function dataStore() external view returns (address);

    function sendWnt(address receiver, uint256 amount) external payable;

    function sendTokens(address token, address receiver, uint256 amount) external payable;

    function depositHandler() external view returns (address);

    function createDeposit(CreateDepositParams calldata params) external payable returns (bytes32);
}

interface IGmxDataStore {
    function containsBytes32(bytes32 setKey, bytes32 value) external view returns (bool);
}

contract MagicGmRouterOrder is IMagicGmRouterOrder {
    using SafeTransferLib for address;

    error ErrFinalized();
    error ErrNotOnwer();
    error ErrAlreadyInitialized();

    bytes32 public constant DEPOSIT_LIST = keccak256(abi.encode("DEPOSIT_LIST"));

    IMagicGm public immutable MAGIC_GM;
    IERC20 public immutable USDC;
    IERC20 public immutable GM_BTC;
    IERC20 public immutable GM_ETH;
    IERC20 public immutable GM_ARB;
    IGmxV2ExchangeRouter public immutable GMX_ROUTER;
    IGmxDataStore public immutable DATASTORE;
    address public immutable DEPOSIT_VAULT;
    address public immutable SYNTHETICS_ROUTER;

    address public owner;
    bytes32 public key;
    bool public finalized;

    modifier onlyOwner() virtual {
        if (msg.sender != owner) {
            revert ErrNotOnwer();
        }
        _;
    }

    constructor(
        IMagicGm _magicGm,
        IERC20 _usdc,
        IERC20 _gmBTC,
        IERC20 _gmEth,
        IERC20 _gmArb,
        IGmxV2ExchangeRouter _gmxRouter,
        address _syntheticsRouter
    ) {
        MAGIC_GM = _magicGm;
        USDC = _usdc;
        GM_BTC = _gmBTC;
        GM_ETH = _gmEth;
        GM_ARB = _gmArb;
        GMX_ROUTER = _gmxRouter;
        SYNTHETICS_ROUTER = _syntheticsRouter;
        DATASTORE = IGmxDataStore(_gmxRouter.dataStore());
        DEPOSIT_VAULT = IGmxV2DepositHandler(_gmxRouter.depositHandler()).depositVault();
    }

    function init(address _owner) external payable {
        if (owner != address(0)) {
            revert ErrAlreadyInitialized();
        }

        owner = _owner;

        uint256 usdcBalance = USDC.balanceOf(address(this));
        address(USDC).safeApprove(address(SYNTHETICS_ROUTER), usdcBalance);

        GMX_ROUTER.sendWnt{value: msg.value}(address(DEPOSIT_VAULT), msg.value);
        GMX_ROUTER.sendTokens(address(USDC), address(DEPOSIT_VAULT), usdcBalance);

        CreateDepositParams memory params = CreateDepositParams({
            receiver: address(this),
            callbackContract: address(0),
            uiFeeReceiver: address(0),
            market: address(GM_ETH),
            initialLongToken: address(GM_BTC), // todo
            initialShortToken: address(GM_ETH), // todo
            longTokenSwapPath: new address[](0),
            shortTokenSwapPath: new address[](0),
            minMarketTokens: 0, // todo
            shouldUnwrapNativeToken: false,
            executionFee: 0, // todo
            callbackGasLimit: 0
        });

        key = GMX_ROUTER.createDeposit(params);
    }

    function isActive() public view returns (bool) {
        return DATASTORE.containsBytes32(DEPOSIT_LIST, key);
    }

    function claim() public onlyOwner {
        if (finalized) {
            revert ErrFinalized();
        }

        _withdrawAll();
        finalized = true;
    }

    function _withdrawAll() internal {
        address(USDC).safeTransferAll(msg.sender);
        address(GM_BTC).safeTransferAll(msg.sender);
        address(GM_ETH).safeTransferAll(msg.sender);
        address(GM_ARB).safeTransferAll(msg.sender);
        msg.sender.safeTransferETH(address(this).balance);
    }

    function withdrawAll() public onlyOwner {
        _withdrawAll();
    }

    function tokenIn() external view returns (IERC20) {
        return USDC;
    }
}

contract MagicGmRouter {
    using SafeTransferLib for address;

    event LogOrderCreated(address indexed order, address indexed account, uint256 nonce);
    event LogOrderFinalized(address indexed order, address indexed account, uint256 nonce);

    address public immutable orderImplementation;
    IERC20 public immutable tokenIn;

    mapping(address account => uint nonce) public nonces;

    constructor(IMagicGmRouterOrder _orderImplementation) {
        orderImplementation = address(_orderImplementation);
        tokenIn = _orderImplementation.tokenIn();
    }

    function createOrder(uint256 _amountIn) public payable returns (address order) {
        nonces[msg.sender]++;

        (bytes32 salt, bytes memory data) = _getOrderDeterministicAddressParameters(msg.sender, nonces[msg.sender]);
        order = LibClone.cloneDeterministic(orderImplementation, data, salt);
        address(tokenIn).safeTransferFrom(msg.sender, order, _amountIn);
        IMagicGmRouterOrder(order).init{value: msg.value}(msg.sender);

        emit LogOrderCreated(order, msg.sender, nonces[msg.sender]);
    }

    function finalizeOrder(uint256 _nonce) public {
        address order = getOrderAddress(msg.sender, _nonce);
        IMagicGmRouterOrder(order).claim();

        emit LogOrderFinalized(order, msg.sender, _nonce);
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
