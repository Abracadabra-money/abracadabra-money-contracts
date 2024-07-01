// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

interface IMiniChefV2 {
    struct PoolInfo {
        uint128 accSushiPerShare;
        uint64 lastRewardTime;
        uint64 allocPoint;
        uint256 depositIncentives;
    }

    error CallerIsNotAllowed();
    error CallerIsNotGovernor();
    error CallerIsNotOperator();
    error FailSendETH();

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount, address indexed to, uint256 incentive);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount, address indexed to);
    event EmergencyWithdrawal(address indexed caller, address indexed receiver, address[] tokens, uint256 nativeBalanc);
    event GovernorUpdated(address _oldGovernor, address _newGovernor);
    event Harvest(address indexed user, uint256 indexed pid, uint256 amount);
    event LogPoolAddition(uint256 indexed pid, uint256 allocPoint, address indexed lpToken, address indexed rewarder);
    event LogSetPool(uint256 indexed pid, uint256 allocPoint, address indexed rewarder, bool overwrite);
    event LogSushiPerSecond(uint256 sushiPerSecond);
    event LogUpdatePool(uint256 indexed pid, uint64 lastRewardTime, uint256 lpSupply, uint256 accSushiPerShare);
    event OperatorAdded(address _newOperator);
    event OperatorRemoved(address _operator);
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount, address indexed to);

    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
    function GOVERNOR() external view returns (bytes32);
    function OPERATOR() external view returns (bytes32);
    function SUSHI() external view returns (address);
    function add(uint256 allocPoint, address _lpToken, address _rewarder, uint256 _depositIncentives) external;
    function addOperator(address _newOperator) external;
    function batch(bytes[] memory calls, bool revertOnFail)
        external
        payable
        returns (bool[] memory successes, bytes[] memory results);
    function deadline() external view returns (uint256);
    function deposit(uint256 pid, uint256 amount, address to) external;
    function emergencyWithdraw(uint256 pid, address to) external;
    function emergencyWithdraw(address _to, address[] memory _assets, bool _withdrawNative) external;
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    function grantRole(bytes32 role, address account) external;
    function harvest(uint256 pid, address to) external;
    function hasRole(bytes32 role, address account) external view returns (bool);
    function incentiveReceiver() external view returns (address);
    function incentivesOn() external view returns (bool);
    function lpToken(uint256) external view returns (address);
    function massUpdatePools(uint256[] memory pids) external;
    function migrate(uint256 _pid) external;
    function migrator() external view returns (address);
    function pendingSushi(uint256 _pid, address _user) external view returns (uint256 pending);
    function permitToken(
        address token,
        address from,
        address to,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
    function poolInfo(uint256)
        external
        view
        returns (uint128 accSushiPerShare, uint64 lastRewardTime, uint64 allocPoint, uint256 depositIncentives);
    function poolLength() external view returns (uint256 pools);
    function removeOperator(address _operator) external;
    function renounceRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
    function rewarder(uint256) external view returns (address);
    function set(uint256 _pid, uint256 _allocPoint, address _rewarder, bool overwrite) external;
    function setDeadline(uint256 _deadline) external;
    function setMigrator(address _migrator) external;
    function setSushiPerSecond(uint256 _sushiPerSecond) external;
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
    function sushiPerSecond() external view returns (uint256);
    function toggleIncentives() external;
    function totalAllocPoint() external view returns (uint256);
    function updateGovernor(address _newGovernor) external;
    function updatePool(uint256 pid) external returns (PoolInfo memory pool);
    function updatePoolIncentive(uint256 pid, uint256 _depositIncentives) external;
    function userInfo(uint256, address) external view returns (uint256 amount, int256 rewardDebt);
    function withdraw(uint256 pid, uint256 amount, address to) external;
    function withdrawAndHarvest(uint256 pid, uint256 amount, address to) external;
}