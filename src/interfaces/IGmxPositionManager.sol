// SPDX-License-Identifier: UNLICENSED
// !! THIS FILE WAS AUTOGENERATED BY abi-to-sol v0.6.6. SEE SOURCE BELOW. !!
pragma solidity >=0.7.0 <0.9.0;

interface IGmxPositionManager {
    event Callback(address callbackTarget, bool success);
    event CancelDecreasePosition(
        address indexed account,
        address[] path,
        address indexToken,
        uint256 collateralDelta,
        uint256 sizeDelta,
        bool isLong,
        address receiver,
        uint256 acceptablePrice,
        uint256 minOut,
        uint256 executionFee,
        uint256 blockGap,
        uint256 timeGap
    );
    event CancelIncreasePosition(
        address indexed account,
        address[] path,
        address indexToken,
        uint256 amountIn,
        uint256 minOut,
        uint256 sizeDelta,
        bool isLong,
        uint256 acceptablePrice,
        uint256 executionFee,
        uint256 blockGap,
        uint256 timeGap
    );
    event CreateDecreasePosition(
        address indexed account,
        address[] path,
        address indexToken,
        uint256 collateralDelta,
        uint256 sizeDelta,
        bool isLong,
        address receiver,
        uint256 acceptablePrice,
        uint256 minOut,
        uint256 executionFee,
        uint256 index,
        uint256 queueIndex,
        uint256 blockNumber,
        uint256 blockTime
    );
    event CreateIncreasePosition(
        address indexed account,
        address[] path,
        address indexToken,
        uint256 amountIn,
        uint256 minOut,
        uint256 sizeDelta,
        bool isLong,
        uint256 acceptablePrice,
        uint256 executionFee,
        uint256 index,
        uint256 queueIndex,
        uint256 blockNumber,
        uint256 blockTime,
        uint256 gasPrice
    );
    event DecreasePositionReferral(
        address account,
        uint256 sizeDelta,
        uint256 marginFeeBasisPoints,
        bytes32 referralCode,
        address referrer
    );
    event ExecuteDecreasePosition(
        address indexed account,
        address[] path,
        address indexToken,
        uint256 collateralDelta,
        uint256 sizeDelta,
        bool isLong,
        address receiver,
        uint256 acceptablePrice,
        uint256 minOut,
        uint256 executionFee,
        uint256 blockGap,
        uint256 timeGap
    );
    event ExecuteIncreasePosition(
        address indexed account,
        address[] path,
        address indexToken,
        uint256 amountIn,
        uint256 minOut,
        uint256 sizeDelta,
        bool isLong,
        uint256 acceptablePrice,
        uint256 executionFee,
        uint256 blockGap,
        uint256 timeGap
    );
    event IncreasePositionReferral(
        address account,
        uint256 sizeDelta,
        uint256 marginFeeBasisPoints,
        bytes32 referralCode,
        address referrer
    );
    event SetAdmin(address admin);
    event SetCallbackGasLimit(uint256 callbackGasLimit);
    event SetDelayValues(uint256 minBlockDelayKeeper, uint256 minTimeDelayPublic, uint256 maxTimeDelay);
    event SetDepositFee(uint256 depositFee);
    event SetIncreasePositionBufferBps(uint256 increasePositionBufferBps);
    event SetIsLeverageEnabled(bool isLeverageEnabled);
    event SetMaxGlobalSizes(address[] tokens, uint256[] longSizes, uint256[] shortSizes);
    event SetMinExecutionFee(uint256 minExecutionFee);
    event SetPositionKeeper(address indexed account, bool isActive);
    event SetReferralStorage(address referralStorage);
    event SetRequestKeysStartValues(uint256 increasePositionRequestKeysStart, uint256 decreasePositionRequestKeysStart);
    event WithdrawFees(address token, address receiver, uint256 amount);

    function BASIS_POINTS_DIVISOR() external view returns (uint256);

    function admin() external view returns (address);

    function approve(address _token, address _spender, uint256 _amount) external;

    function callbackGasLimit() external view returns (uint256);

    function cancelDecreasePosition(bytes32 _key, address _executionFeeReceiver) external returns (bool);

    function cancelIncreasePosition(bytes32 _key, address _executionFeeReceiver) external returns (bool);

    function createDecreasePosition(
        address[] memory _path,
        address _indexToken,
        uint256 _collateralDelta,
        uint256 _sizeDelta,
        bool _isLong,
        address _receiver,
        uint256 _acceptablePrice,
        uint256 _minOut,
        uint256 _executionFee,
        bool _withdrawETH,
        address _callbackTarget
    ) external payable returns (bytes32);

    function createIncreasePosition(
        address[] memory _path,
        address _indexToken,
        uint256 _amountIn,
        uint256 _minOut,
        uint256 _sizeDelta,
        bool _isLong,
        uint256 _acceptablePrice,
        uint256 _executionFee,
        bytes32 _referralCode,
        address _callbackTarget
    ) external payable returns (bytes32);

    function createIncreasePositionETH(
        address[] memory _path,
        address _indexToken,
        uint256 _minOut,
        uint256 _sizeDelta,
        bool _isLong,
        uint256 _acceptablePrice,
        uint256 _executionFee,
        bytes32 _referralCode,
        address _callbackTarget
    ) external payable returns (bytes32);

    function decreasePositionRequestKeys(uint256) external view returns (bytes32);

    function decreasePositionRequestKeysStart() external view returns (uint256);

    function decreasePositionRequests(
        bytes32
    )
        external
        view
        returns (
            address account,
            address indexToken,
            uint256 collateralDelta,
            uint256 sizeDelta,
            bool isLong,
            address receiver,
            uint256 acceptablePrice,
            uint256 minOut,
            uint256 executionFee,
            uint256 blockNumber,
            uint256 blockTime,
            bool withdrawETH,
            address callbackTarget
        );

    function decreasePositionsIndex(address) external view returns (uint256);

    function depositFee() external view returns (uint256);

    function executeDecreasePosition(bytes32 _key, address _executionFeeReceiver) external returns (bool);

    function executeDecreasePositions(uint256 _endIndex, address _executionFeeReceiver) external;

    function executeIncreasePosition(bytes32 _key, address _executionFeeReceiver) external returns (bool);

    function executeIncreasePositions(uint256 _endIndex, address _executionFeeReceiver) external;

    function feeReserves(address) external view returns (uint256);

    function getDecreasePositionRequestPath(bytes32 _key) external view returns (address[] memory);

    function getIncreasePositionRequestPath(bytes32 _key) external view returns (address[] memory);

    function getRequestKey(address _account, uint256 _index) external pure returns (bytes32);

    function getRequestQueueLengths() external view returns (uint256, uint256, uint256, uint256);

    function gov() external view returns (address);

    function increasePositionBufferBps() external view returns (uint256);

    function increasePositionRequestKeys(uint256) external view returns (bytes32);

    function increasePositionRequestKeysStart() external view returns (uint256);

    function increasePositionRequests(
        bytes32
    )
        external
        view
        returns (
            address account,
            address indexToken,
            uint256 amountIn,
            uint256 minOut,
            uint256 sizeDelta,
            bool isLong,
            uint256 acceptablePrice,
            uint256 executionFee,
            uint256 blockNumber,
            uint256 blockTime,
            bool hasCollateralInETH,
            address callbackTarget
        );

    function increasePositionsIndex(address) external view returns (uint256);

    function isLeverageEnabled() external view returns (bool);

    function isPositionKeeper(address) external view returns (bool);

    function maxGlobalLongSizes(address) external view returns (uint256);

    function maxGlobalShortSizes(address) external view returns (uint256);

    function maxTimeDelay() external view returns (uint256);

    function minBlockDelayKeeper() external view returns (uint256);

    function minExecutionFee() external view returns (uint256);

    function minTimeDelayPublic() external view returns (uint256);

    function referralStorage() external view returns (address);

    function router() external view returns (address);

    function sendValue(address _receiver, uint256 _amount) external;

    function setAdmin(address _admin) external;

    function setCallbackGasLimit(uint256 _callbackGasLimit) external;

    function setDelayValues(uint256 _minBlockDelayKeeper, uint256 _minTimeDelayPublic, uint256 _maxTimeDelay) external;

    function setDepositFee(uint256 _depositFee) external;

    function setGov(address _gov) external;

    function setIncreasePositionBufferBps(uint256 _increasePositionBufferBps) external;

    function setIsLeverageEnabled(bool _isLeverageEnabled) external;

    function setMaxGlobalSizes(address[] memory _tokens, uint256[] memory _longSizes, uint256[] memory _shortSizes) external;

    function setMinExecutionFee(uint256 _minExecutionFee) external;

    function setPositionKeeper(address _account, bool _isActive) external;

    function setReferralStorage(address _referralStorage) external;

    function setRequestKeysStartValues(uint256 _increasePositionRequestKeysStart, uint256 _decreasePositionRequestKeysStart) external;

    function shortsTracker() external view returns (address);

    function vault() external view returns (address);

    function weth() external view returns (address);

    function withdrawFees(address _token, address _receiver) external;

    receive() external payable;
}

// THIS FILE WAS AUTOGENERATED FROM THE FOLLOWING ABI JSON:
/*
[{"inputs":[{"internalType":"address","name":"_vault","type":"address"},{"internalType":"address","name":"_router","type":"address"},{"internalType":"address","name":"_weth","type":"address"},{"internalType":"address","name":"_shortsTracker","type":"address"},{"internalType":"uint256","name":"_depositFee","type":"uint256"},{"internalType":"uint256","name":"_minExecutionFee","type":"uint256"}],"stateMutability":"nonpayable","type":"constructor"},{"anonymous":false,"inputs":[{"indexed":false,"internalType":"address","name":"callbackTarget","type":"address"},{"indexed":false,"internalType":"bool","name":"success","type":"bool"}],"name":"Callback","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"account","type":"address"},{"indexed":false,"internalType":"address[]","name":"path","type":"address[]"},{"indexed":false,"internalType":"address","name":"indexToken","type":"address"},{"indexed":false,"internalType":"uint256","name":"collateralDelta","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"sizeDelta","type":"uint256"},{"indexed":false,"internalType":"bool","name":"isLong","type":"bool"},{"indexed":false,"internalType":"address","name":"receiver","type":"address"},{"indexed":false,"internalType":"uint256","name":"acceptablePrice","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"minOut","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"executionFee","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"blockGap","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"timeGap","type":"uint256"}],"name":"CancelDecreasePosition","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"account","type":"address"},{"indexed":false,"internalType":"address[]","name":"path","type":"address[]"},{"indexed":false,"internalType":"address","name":"indexToken","type":"address"},{"indexed":false,"internalType":"uint256","name":"amountIn","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"minOut","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"sizeDelta","type":"uint256"},{"indexed":false,"internalType":"bool","name":"isLong","type":"bool"},{"indexed":false,"internalType":"uint256","name":"acceptablePrice","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"executionFee","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"blockGap","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"timeGap","type":"uint256"}],"name":"CancelIncreasePosition","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"account","type":"address"},{"indexed":false,"internalType":"address[]","name":"path","type":"address[]"},{"indexed":false,"internalType":"address","name":"indexToken","type":"address"},{"indexed":false,"internalType":"uint256","name":"collateralDelta","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"sizeDelta","type":"uint256"},{"indexed":false,"internalType":"bool","name":"isLong","type":"bool"},{"indexed":false,"internalType":"address","name":"receiver","type":"address"},{"indexed":false,"internalType":"uint256","name":"acceptablePrice","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"minOut","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"executionFee","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"index","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"queueIndex","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"blockNumber","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"blockTime","type":"uint256"}],"name":"CreateDecreasePosition","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"account","type":"address"},{"indexed":false,"internalType":"address[]","name":"path","type":"address[]"},{"indexed":false,"internalType":"address","name":"indexToken","type":"address"},{"indexed":false,"internalType":"uint256","name":"amountIn","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"minOut","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"sizeDelta","type":"uint256"},{"indexed":false,"internalType":"bool","name":"isLong","type":"bool"},{"indexed":false,"internalType":"uint256","name":"acceptablePrice","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"executionFee","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"index","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"queueIndex","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"blockNumber","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"blockTime","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"gasPrice","type":"uint256"}],"name":"CreateIncreasePosition","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"internalType":"address","name":"account","type":"address"},{"indexed":false,"internalType":"uint256","name":"sizeDelta","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"marginFeeBasisPoints","type":"uint256"},{"indexed":false,"internalType":"bytes32","name":"referralCode","type":"bytes32"},{"indexed":false,"internalType":"address","name":"referrer","type":"address"}],"name":"DecreasePositionReferral","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"account","type":"address"},{"indexed":false,"internalType":"address[]","name":"path","type":"address[]"},{"indexed":false,"internalType":"address","name":"indexToken","type":"address"},{"indexed":false,"internalType":"uint256","name":"collateralDelta","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"sizeDelta","type":"uint256"},{"indexed":false,"internalType":"bool","name":"isLong","type":"bool"},{"indexed":false,"internalType":"address","name":"receiver","type":"address"},{"indexed":false,"internalType":"uint256","name":"acceptablePrice","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"minOut","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"executionFee","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"blockGap","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"timeGap","type":"uint256"}],"name":"ExecuteDecreasePosition","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"account","type":"address"},{"indexed":false,"internalType":"address[]","name":"path","type":"address[]"},{"indexed":false,"internalType":"address","name":"indexToken","type":"address"},{"indexed":false,"internalType":"uint256","name":"amountIn","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"minOut","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"sizeDelta","type":"uint256"},{"indexed":false,"internalType":"bool","name":"isLong","type":"bool"},{"indexed":false,"internalType":"uint256","name":"acceptablePrice","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"executionFee","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"blockGap","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"timeGap","type":"uint256"}],"name":"ExecuteIncreasePosition","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"internalType":"address","name":"account","type":"address"},{"indexed":false,"internalType":"uint256","name":"sizeDelta","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"marginFeeBasisPoints","type":"uint256"},{"indexed":false,"internalType":"bytes32","name":"referralCode","type":"bytes32"},{"indexed":false,"internalType":"address","name":"referrer","type":"address"}],"name":"IncreasePositionReferral","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"internalType":"address","name":"admin","type":"address"}],"name":"SetAdmin","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"internalType":"uint256","name":"callbackGasLimit","type":"uint256"}],"name":"SetCallbackGasLimit","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"internalType":"uint256","name":"minBlockDelayKeeper","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"minTimeDelayPublic","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"maxTimeDelay","type":"uint256"}],"name":"SetDelayValues","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"internalType":"uint256","name":"depositFee","type":"uint256"}],"name":"SetDepositFee","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"internalType":"uint256","name":"increasePositionBufferBps","type":"uint256"}],"name":"SetIncreasePositionBufferBps","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"internalType":"bool","name":"isLeverageEnabled","type":"bool"}],"name":"SetIsLeverageEnabled","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"internalType":"address[]","name":"tokens","type":"address[]"},{"indexed":false,"internalType":"uint256[]","name":"longSizes","type":"uint256[]"},{"indexed":false,"internalType":"uint256[]","name":"shortSizes","type":"uint256[]"}],"name":"SetMaxGlobalSizes","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"internalType":"uint256","name":"minExecutionFee","type":"uint256"}],"name":"SetMinExecutionFee","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"account","type":"address"},{"indexed":false,"internalType":"bool","name":"isActive","type":"bool"}],"name":"SetPositionKeeper","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"internalType":"address","name":"referralStorage","type":"address"}],"name":"SetReferralStorage","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"internalType":"uint256","name":"increasePositionRequestKeysStart","type":"uint256"},{"indexed":false,"internalType":"uint256","name":"decreasePositionRequestKeysStart","type":"uint256"}],"name":"SetRequestKeysStartValues","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"internalType":"address","name":"token","type":"address"},{"indexed":false,"internalType":"address","name":"receiver","type":"address"},{"indexed":false,"internalType":"uint256","name":"amount","type":"uint256"}],"name":"WithdrawFees","type":"event"},{"inputs":[],"name":"BASIS_POINTS_DIVISOR","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"admin","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"_token","type":"address"},{"internalType":"address","name":"_spender","type":"address"},{"internalType":"uint256","name":"_amount","type":"uint256"}],"name":"approve","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"callbackGasLimit","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"bytes32","name":"_key","type":"bytes32"},{"internalType":"address payable","name":"_executionFeeReceiver","type":"address"}],"name":"cancelDecreasePosition","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"bytes32","name":"_key","type":"bytes32"},{"internalType":"address payable","name":"_executionFeeReceiver","type":"address"}],"name":"cancelIncreasePosition","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address[]","name":"_path","type":"address[]"},{"internalType":"address","name":"_indexToken","type":"address"},{"internalType":"uint256","name":"_collateralDelta","type":"uint256"},{"internalType":"uint256","name":"_sizeDelta","type":"uint256"},{"internalType":"bool","name":"_isLong","type":"bool"},{"internalType":"address","name":"_receiver","type":"address"},{"internalType":"uint256","name":"_acceptablePrice","type":"uint256"},{"internalType":"uint256","name":"_minOut","type":"uint256"},{"internalType":"uint256","name":"_executionFee","type":"uint256"},{"internalType":"bool","name":"_withdrawETH","type":"bool"},{"internalType":"address","name":"_callbackTarget","type":"address"}],"name":"createDecreasePosition","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"payable","type":"function"},{"inputs":[{"internalType":"address[]","name":"_path","type":"address[]"},{"internalType":"address","name":"_indexToken","type":"address"},{"internalType":"uint256","name":"_amountIn","type":"uint256"},{"internalType":"uint256","name":"_minOut","type":"uint256"},{"internalType":"uint256","name":"_sizeDelta","type":"uint256"},{"internalType":"bool","name":"_isLong","type":"bool"},{"internalType":"uint256","name":"_acceptablePrice","type":"uint256"},{"internalType":"uint256","name":"_executionFee","type":"uint256"},{"internalType":"bytes32","name":"_referralCode","type":"bytes32"},{"internalType":"address","name":"_callbackTarget","type":"address"}],"name":"createIncreasePosition","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"payable","type":"function"},{"inputs":[{"internalType":"address[]","name":"_path","type":"address[]"},{"internalType":"address","name":"_indexToken","type":"address"},{"internalType":"uint256","name":"_minOut","type":"uint256"},{"internalType":"uint256","name":"_sizeDelta","type":"uint256"},{"internalType":"bool","name":"_isLong","type":"bool"},{"internalType":"uint256","name":"_acceptablePrice","type":"uint256"},{"internalType":"uint256","name":"_executionFee","type":"uint256"},{"internalType":"bytes32","name":"_referralCode","type":"bytes32"},{"internalType":"address","name":"_callbackTarget","type":"address"}],"name":"createIncreasePositionETH","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"payable","type":"function"},{"inputs":[{"internalType":"uint256","name":"","type":"uint256"}],"name":"decreasePositionRequestKeys","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"decreasePositionRequestKeysStart","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"name":"decreasePositionRequests","outputs":[{"internalType":"address","name":"account","type":"address"},{"internalType":"address","name":"indexToken","type":"address"},{"internalType":"uint256","name":"collateralDelta","type":"uint256"},{"internalType":"uint256","name":"sizeDelta","type":"uint256"},{"internalType":"bool","name":"isLong","type":"bool"},{"internalType":"address","name":"receiver","type":"address"},{"internalType":"uint256","name":"acceptablePrice","type":"uint256"},{"internalType":"uint256","name":"minOut","type":"uint256"},{"internalType":"uint256","name":"executionFee","type":"uint256"},{"internalType":"uint256","name":"blockNumber","type":"uint256"},{"internalType":"uint256","name":"blockTime","type":"uint256"},{"internalType":"bool","name":"withdrawETH","type":"bool"},{"internalType":"address","name":"callbackTarget","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"","type":"address"}],"name":"decreasePositionsIndex","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"depositFee","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"bytes32","name":"_key","type":"bytes32"},{"internalType":"address payable","name":"_executionFeeReceiver","type":"address"}],"name":"executeDecreasePosition","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"_endIndex","type":"uint256"},{"internalType":"address payable","name":"_executionFeeReceiver","type":"address"}],"name":"executeDecreasePositions","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"bytes32","name":"_key","type":"bytes32"},{"internalType":"address payable","name":"_executionFeeReceiver","type":"address"}],"name":"executeIncreasePosition","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"_endIndex","type":"uint256"},{"internalType":"address payable","name":"_executionFeeReceiver","type":"address"}],"name":"executeIncreasePositions","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"","type":"address"}],"name":"feeReserves","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"bytes32","name":"_key","type":"bytes32"}],"name":"getDecreasePositionRequestPath","outputs":[{"internalType":"address[]","name":"","type":"address[]"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"bytes32","name":"_key","type":"bytes32"}],"name":"getIncreasePositionRequestPath","outputs":[{"internalType":"address[]","name":"","type":"address[]"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"_account","type":"address"},{"internalType":"uint256","name":"_index","type":"uint256"}],"name":"getRequestKey","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"pure","type":"function"},{"inputs":[],"name":"getRequestQueueLengths","outputs":[{"internalType":"uint256","name":"","type":"uint256"},{"internalType":"uint256","name":"","type":"uint256"},{"internalType":"uint256","name":"","type":"uint256"},{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"gov","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"increasePositionBufferBps","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"","type":"uint256"}],"name":"increasePositionRequestKeys","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"increasePositionRequestKeysStart","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"name":"increasePositionRequests","outputs":[{"internalType":"address","name":"account","type":"address"},{"internalType":"address","name":"indexToken","type":"address"},{"internalType":"uint256","name":"amountIn","type":"uint256"},{"internalType":"uint256","name":"minOut","type":"uint256"},{"internalType":"uint256","name":"sizeDelta","type":"uint256"},{"internalType":"bool","name":"isLong","type":"bool"},{"internalType":"uint256","name":"acceptablePrice","type":"uint256"},{"internalType":"uint256","name":"executionFee","type":"uint256"},{"internalType":"uint256","name":"blockNumber","type":"uint256"},{"internalType":"uint256","name":"blockTime","type":"uint256"},{"internalType":"bool","name":"hasCollateralInETH","type":"bool"},{"internalType":"address","name":"callbackTarget","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"","type":"address"}],"name":"increasePositionsIndex","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"isLeverageEnabled","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"","type":"address"}],"name":"isPositionKeeper","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"","type":"address"}],"name":"maxGlobalLongSizes","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"","type":"address"}],"name":"maxGlobalShortSizes","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"maxTimeDelay","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"minBlockDelayKeeper","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"minExecutionFee","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"minTimeDelayPublic","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"referralStorage","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"router","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address payable","name":"_receiver","type":"address"},{"internalType":"uint256","name":"_amount","type":"uint256"}],"name":"sendValue","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"_admin","type":"address"}],"name":"setAdmin","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"_callbackGasLimit","type":"uint256"}],"name":"setCallbackGasLimit","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"_minBlockDelayKeeper","type":"uint256"},{"internalType":"uint256","name":"_minTimeDelayPublic","type":"uint256"},{"internalType":"uint256","name":"_maxTimeDelay","type":"uint256"}],"name":"setDelayValues","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"_depositFee","type":"uint256"}],"name":"setDepositFee","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"_gov","type":"address"}],"name":"setGov","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"_increasePositionBufferBps","type":"uint256"}],"name":"setIncreasePositionBufferBps","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"bool","name":"_isLeverageEnabled","type":"bool"}],"name":"setIsLeverageEnabled","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address[]","name":"_tokens","type":"address[]"},{"internalType":"uint256[]","name":"_longSizes","type":"uint256[]"},{"internalType":"uint256[]","name":"_shortSizes","type":"uint256[]"}],"name":"setMaxGlobalSizes","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"_minExecutionFee","type":"uint256"}],"name":"setMinExecutionFee","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"_account","type":"address"},{"internalType":"bool","name":"_isActive","type":"bool"}],"name":"setPositionKeeper","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"_referralStorage","type":"address"}],"name":"setReferralStorage","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"_increasePositionRequestKeysStart","type":"uint256"},{"internalType":"uint256","name":"_decreasePositionRequestKeysStart","type":"uint256"}],"name":"setRequestKeysStartValues","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"shortsTracker","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"vault","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"weth","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"_token","type":"address"},{"internalType":"address","name":"_receiver","type":"address"}],"name":"withdrawFees","outputs":[],"stateMutability":"nonpayable","type":"function"},{"stateMutability":"payable","type":"receive"}]
*/
