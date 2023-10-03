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

    function init(address _owner, MagicGmRouterOrderParams[] memory _params) external payable;

    function usdc() external view returns (address);
}

interface IMagicGm {
    function deposit(uint256 btcAmount, uint256 ethAmount, uint256 arbAmount, address receiver) external returns (uint256 shares);
}

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

struct MagicGmRouterOrderParams {
    uint256 usdcAmount;
    uint256 executionFee;
    uint256 minMarketTokens;
}

contract MagicGmRouterOrder is IMagicGmRouterOrder {
    using SafeTransferLib for address;

    error ErrFinalized();
    error ErrNotOnwer();
    error ErrAlreadyInitialized();

    bytes32 public constant DEPOSIT_LIST = keccak256(abi.encode("DEPOSIT_LIST"));

    IMagicGm public immutable MAGIC_GM;
    address public immutable USDC;
    address public immutable GM_BTC;
    address public immutable GM_ETH;
    address public immutable GM_ARB;
    address public immutable WBTC;
    address public immutable WETH;
    address public immutable ARB;
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
        address _usdc,
        address _gmBTC,
        address _gmEth,
        address _gmArb,
        address _wbtc,
        address _weth,
        address _arb,
        IGmxV2ExchangeRouter _gmxRouter,
        address _syntheticsRouter
    ) {
        MAGIC_GM = _magicGm;
        USDC = _usdc;
        GM_BTC = _gmBTC;
        GM_ETH = _gmEth;
        GM_ARB = _gmArb;
        WBTC = _wbtc;
        WETH = _weth;
        ARB = _arb;
        GMX_ROUTER = _gmxRouter;
        SYNTHETICS_ROUTER = _syntheticsRouter;
        DATASTORE = IGmxDataStore(_gmxRouter.dataStore());
        DEPOSIT_VAULT = IGmxV2DepositHandler(_gmxRouter.depositHandler()).depositVault();
    }

    function init(address _owner, MagicGmRouterOrderParams[] memory _params) external payable {
        if (owner != address(0)) {
            revert ErrAlreadyInitialized();
        }

        owner = _owner;

        uint256 usdcBalance = USDC.balanceOf(address(this));
        address(USDC).safeApprove(address(SYNTHETICS_ROUTER), usdcBalance);

        _createDepositOrder(GM_BTC, WBTC, _params[0].usdcAmount, _params[0].minMarketTokens, _params[0].executionFee);
        _createDepositOrder(GM_ETH, WETH, _params[1].usdcAmount, _params[1].minMarketTokens, _params[1].executionFee);
        _createDepositOrder(GM_ARB, ARB, _params[2].usdcAmount, _params[2].minMarketTokens, _params[2].executionFee);
    }

    function _createDepositOrder(
        address _gmToken,
        address _underlyingToken,
        uint256 _usdcAmount,
        uint256 _minGmTokenOutput,
        uint256 _executionFee
    ) private returns (bytes32) {
        GMX_ROUTER.sendWnt{value: _executionFee}(address(DEPOSIT_VAULT), _executionFee);
        GMX_ROUTER.sendTokens(address(USDC), address(DEPOSIT_VAULT), _usdcAmount);

        address[] memory emptyPath = new address[](0);

        CreateDepositParams memory params = CreateDepositParams({
            receiver: address(this),
            callbackContract: address(0),
            uiFeeReceiver: address(0),
            market: _gmToken,
            initialLongToken: _underlyingToken,
            initialShortToken: USDC,
            longTokenSwapPath: emptyPath,
            shortTokenSwapPath: emptyPath,
            minMarketTokens: _minGmTokenOutput,
            shouldUnwrapNativeToken: false,
            executionFee: _executionFee,
            callbackGasLimit: 0
        });

        return GMX_ROUTER.createDeposit(params);
    }

    function isActive() public view returns (bool) {
        return DATASTORE.containsBytes32(DEPOSIT_LIST, key);
    }

    function claim() public onlyOwner {
        if (finalized) {
            revert ErrFinalized();
        }

        address(GM_ETH).safeApprove(address(MAGIC_GM), GM_ETH.balanceOf(address(this)));
        address(GM_BTC).safeApprove(address(MAGIC_GM), GM_BTC.balanceOf(address(this)));
        address(GM_ARB).safeApprove(address(MAGIC_GM), GM_ARB.balanceOf(address(this)));

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

    function usdc() external view returns (address) {
        return USDC;
    }
}

contract MagicGmRouter {
    using SafeTransferLib for address;

    error ErrInvalidParams();

    event LogOrderCreated(address indexed order, address indexed account, uint256 nonce);
    event LogOrderFinalized(address indexed order, address indexed account, uint256 nonce);

    address public immutable orderImplementation;
    address public immutable usdc;

    mapping(address account => uint nonce) public nonces;

    constructor(IMagicGmRouterOrder _orderImplementation) {
        orderImplementation = address(_orderImplementation);
        usdc = _orderImplementation.usdc();
    }

    function createOrder(uint256 _usdcAmount, MagicGmRouterOrderParams[] memory params) public payable returns (address order) {
        if(params.length != 3) {
           revert ErrInvalidParams();
        }

        nonces[msg.sender]++;

        (bytes32 salt, bytes memory data) = _getOrderDeterministicAddressParameters(msg.sender, nonces[msg.sender]);
        order = LibClone.cloneDeterministic(orderImplementation, data, salt);
        usdc.safeTransferFrom(msg.sender, order, _usdcAmount);
        IMagicGmRouterOrder(order).init{value: msg.value}(msg.sender, params);

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
