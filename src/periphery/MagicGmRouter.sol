// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {OperatableV2} from "mixins/OperatableV2.sol";
import {Owned} from "solmate/utils/Owned.sol";
import {LibClone} from "solady/utils/LibClone.sol";

contract ArbitrumMagicGmRouterOrder is Owned {
    IERC20 public constant USDC = IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
    IERC20 public constant GM_BTC = IERC20(0x47c031236e19d024b42f8AE6780E44A573170703);
    IERC20 public constant GM_ETH = IERC20(0x70d95587d40A2caf56bd97485aB3Eec10Bee6336);
    IERC20 public constant GM_ARB = IERC20(0xC25cEf6061Cf5dE5eb761b50E4743c1F5D7E5407);

    uint256 public immutable usdcAmount;
    uint256 public immutable minGmEthAmount;
    uint256 public immutable minGmBtcAmount;
    uint256 public immutable minGmArbAmount;

    constructor(
        uint256 _usdcAmount,
        uint256 _minGmEthAmount,
        uint256 _minGmBtcAmount,
        uint256 _minGmArbAmount,
        address _owner
    ) Owned(_owner) {
        usdcAmount = _usdcAmount;
        minGmEthAmount = _minGmEthAmount;
        minGmBtcAmount = _minGmBtcAmount;
        minGmArbAmount = _minGmArbAmount;
    }

    function claim() public onlyOwner {}

    function rescue() public onlyOwner {}
}

contract MagicGmRouter {
    MagicGmRouterOrder public immutable orderImplementation;

    mapping(address account => uint nonce) public nonces;

    constructor(MagicGmRouterOrder _orderImplementation) {
        orderImplementation = _orderImplementation;
    }

    function createOrder() public returns (address) {
        (bytes32 salt, bytes memory data) = _getOrderDeterministicAddressParameters(msg.sender, nonces[msg.sender]++);
        return LibClone.cloneDeterministic(orderImplementation, data, salt);
    }

    function getOrderAddress(address account, uint nonce) public view returns (address) {
        (bytes32 salt, bytes memory data) = _getOrderDeterministicAddressParameters(account, nonce);
        return LibClone.predictDeterministicAddress(orderImplementation, data, salt, address(this));
    }

    function _getOrderDeterministicAddressParameters(address account, uint nonce) private view returns (bytes32 salt, bytes memory data) {
        salt = keccak256(abi.encodePacked(account, nonce));
        data = abi.encodePacked(address(orderImplementation));
    }
}
