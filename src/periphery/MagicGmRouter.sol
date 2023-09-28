// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {OperatableV2} from "mixins/OperatableV2.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

interface IMagicGmRouterOrder {
    function tokenIn() external view returns (IERC20);
}

interface IMagicGm {}

interface IGmxV2ExchangeRouter {}

// 0xD9AebEA68DE4b4A3B58833e1bc2AEB9682883AB0
interface IGmxDepositHandler {
    function dataStore() external view returns (address);
}

// 0xFD70de6b91282D8017aA4E741e9Ae325CAb992d8
interface IGmxDataStore {

}

contract ArbitrumMagicGmRouterOrder is IMagicGmRouterOrder {
    using SafeTransferLib for IERC20;

    error ErrFinalized();
    error ErrNotOnwer();

    bytes32 public constant DEPOSIT_LIST = keccak256(abi.encode("DEPOSIT_LIST"));
    IMagicGm public constant MAGIC_GM = IMagicGm(0xFEa7a6a0B346362BF88A9e4A88416B77a57D6c2A); // TODO: update Once deployed

    IERC20 public constant USDC = IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
    IERC20 public constant GM_BTC = IERC20(0x47c031236e19d024b42f8AE6780E44A573170703);
    IERC20 public constant GM_ETH = IERC20(0x70d95587d40A2caf56bd97485aB3Eec10Bee6336);
    IERC20 public constant GM_ARB = IERC20(0xC25cEf6061Cf5dE5eb761b50E4743c1F5D7E5407);
    IGmxV2ExchangeRouter public constant GMX_ROUTER = IGmxV2ExchangeRouter(0x3B070aA6847bd0fB56eFAdB351f49BBb7619dbc2);
    IGmxDataStore public constant DATASTORE = IGmxDataStore(0xFD70de6b91282D8017aA4E741e9Ae325CAb992d8);

    address public owner;
    bytes public key;
    bool public finalized;

    modifier onlyOwner() virtual {
        if (msg.sender != owner) {
            revert ErrNotOnwer();
        }
        _;
    }

// use constructor for mc and then payable init with specificic parsmeter and check for owner != 0x to tell if it was initialized already
    constructor(address _owner) payable {
        owner = _owner;

        // create order using the already transfered in tokenIn

        uint256 usdcBalance = USDC.balanceOf(address(this));
        USDC.safeApprove(address(GMX_ROUTER), usdcBalance);
    }

    function isActive() public view returns (bool) {
        return DATASTORE.containsBytes32(DEPOSIT_LIST, key);
    }

    function claim() public onlyOwner {
        if (finalized) {
            revert ErrFinalized();
        }

        // mint vault using the gm tokens inside this contract
        // fails if there's not enough tokens
        // refund the owner with the remaining tokens that
        // exceed the amount needed to mint the vault ratio

        finalized = true;
    }

    function withdraw() public onlyOwner {
        USDC.safeTransfer(msg.sender, USDC.balanceOf(address(this)));
        GM_BTC.safeTransfer(msg.sender, GM_BTC.balanceOf(address(this)));
        GM_ETH.safeTransfer(msg.sender, GM_ETH.balanceOf(address(this)));
        GM_ARB.safeTransfer(msg.sender, GM_ARB.balanceOf(address(this)));
        payable(msg.sender).call{value: address(this).balance}("");
    }
}

contract MagicGmRouter {
    event LogOrderCreated(address indexed order, address indexed account, uint256 nonce);
    event LogOrderFinalized(address indexed order, address indexed account, uint256 nonce);

    IMagicGmRouterOrder public immutable orderImplementation;
    IMagicGm public immutable magicGm;

    mapping(address account => uint nonce) public nonces;

    constructor(IERC20 _tokenIn, IMagicGm _magicGm) {
        orderImplementation = new MagicGmRouterOrder(_magicGm);
        magicGm = _magicGm;
    }

    function createOrder(uint256 _amountIn) public returns (address order) {
        nonces[msg.sender]++;

        (bytes32 salt, bytes memory data) = _getOrderDeterministicAddressParameters(msg.sender, nonces[msg.sender]);
        order = LibClone.cloneDeterministic(orderImplementation, data, salt);

        emit LogOrderCreated(order, msg.sender, nonces[msg.sender]);
    }

    function finalizeOrder(uint256 _nonce) public {
        address order = getOrderAddress(msg.sender, _nonce);
        IMagicGmRouterOrder(_order).claim();

        emit LogOrderFinalized(order, msg.sender, _nonce);
    }

    function getOrderAddress(address _account, uint _nonce) public view returns (address) {
        (bytes32 salt, bytes memory data) = _getOrderDeterministicAddressParameters(_account, _nonce);
        return LibClone.predictDeterministicAddress(orderImplementation, data, salt, address(this));
    }

    function _getOrderDeterministicAddressParameters(address _account, uint _nonce) private view returns (bytes32 salt, bytes memory data) {
        salt = keccak256(abi.encodePacked(_account, _nonce));
        data = abi.encodePacked(address(orderImplementation));
    }
}
