// SPDX-License-Identifier: BUSL-1.1
// solhint-disable func-name-mixedcase
pragma solidity >=0.8.0;

interface IStargateLPStaking {
    function deposit(uint256 _pid, uint256 _amount) external;

    function emergencyWithdraw(uint256 _pid) external;

    function poolInfo(uint256) external view returns (address lpToken, uint256 allocPoint, uint256 lastReward, uint256 accEmissionPerShare);

    function userInfo(uint256, address) external view returns (uint256 amount, uint256 rewardDebt);

    function withdraw(uint256 _pid, uint256 _amount) external;
}

interface IStargatePool {
    function deltaCredit() external view returns (uint256);

    function totalLiquidity() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function decimals() external view returns (uint256);

    function poolId() external view returns (uint256);

    function localDecimals() external view returns (uint256);

    function token() external view returns (address);

    function balanceOf(address account) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);
}

interface IStargateRouter {
    struct lzTxObj {
        uint256 dstGasForCall;
        uint256 dstNativeAmount;
        bytes dstNativeAddr;
    }

    function addLiquidity(uint256 _poolId, uint256 _amountLD, address _to) external;

    function swap(
        uint16 _dstChainId,
        uint256 _srcPoolId,
        uint256 _dstPoolId,
        address payable _refundAddress,
        uint256 _amountLD,
        uint256 _minAmountLD,
        lzTxObj memory _lzTxParams,
        bytes calldata _to,
        bytes calldata _payload
    ) external payable;

    function redeemRemote(
        uint16 _dstChainId,
        uint256 _srcPoolId,
        uint256 _dstPoolId,
        address payable _refundAddress,
        uint256 _amountLP,
        uint256 _minAmountLD,
        bytes calldata _to,
        lzTxObj memory _lzTxParams
    ) external payable;

    function instantRedeemLocal(uint16 _srcPoolId, uint256 _amountLP, address _to) external returns (uint256);

    function redeemLocal(
        uint16 _dstChainId,
        uint256 _srcPoolId,
        uint256 _dstPoolId,
        address payable _refundAddress,
        uint256 _amountLP,
        bytes calldata _to,
        lzTxObj memory _lzTxParams
    ) external payable;

    function sendCredits(uint16 _dstChainId, uint256 _srcPoolId, uint256 _dstPoolId, address payable _refundAddress) external payable;

    function quoteLayerZeroFee(
        uint16 _dstChainId,
        uint8 _functionType,
        bytes calldata _toAddress,
        bytes calldata _transferAndCallPayload,
        lzTxObj memory _lzTxParams
    ) external view returns (uint256, uint256);
}

interface IStargateToken {
    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function chainId() external view returns (uint16);

    function decimals() external view returns (uint8);

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);

    function dstContractLookup(uint16) external view returns (bytes memory);

    function endpoint() external view returns (address);

    function estimateSendTokensFee(
        uint16 _dstChainId,
        bool _useZro,
        bytes memory txParameters
    ) external view returns (uint256 nativeFee, uint256 zroFee);

    function forceResumeReceive(uint16 _srcChainId, bytes memory _srcAddress) external;

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool);

    function isMain() external view returns (bool);

    function lzReceive(uint16 _srcChainId, bytes memory _fromAddress, uint64 nonce, bytes memory _payload) external;

    function name() external view returns (string memory);

    function owner() external view returns (address);

    function pauseSendTokens(bool _pause) external;

    function paused() external view returns (bool);

    function renounceOwnership() external;

    function sendTokens(
        uint16 _dstChainId,
        bytes memory _to,
        uint256 _qty,
        address zroPaymentAddress,
        bytes memory adapterParam
    ) external payable;

    function setConfig(uint16 _version, uint16 _chainId, uint256 _configType, bytes memory _config) external;

    function setDestination(uint16 _dstChainId, bytes memory _destinationContractAddress) external;

    function setReceiveVersion(uint16 version) external;

    function setSendVersion(uint16 version) external;

    function symbol() external view returns (string memory);

    function totalSupply() external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    function transferOwnership(address newOwner) external;
}
