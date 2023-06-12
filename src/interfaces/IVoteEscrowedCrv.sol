pragma solidity >=0.7.0 <0.9.0;

interface IVoteEscrowedCrv {
    event CommitOwnership(address admin);
    event ApplyOwnership(address admin);
    event Deposit(address indexed provider, uint256 value, uint256 indexed locktime, int128 typeParam, uint256 ts);
    event Withdraw(address indexed provider, uint256 value, uint256 ts);
    event Supply(uint256 prevSupply, uint256 supply);

    function commit_transfer_ownership(address addr) external;

    function apply_transfer_ownership() external;

    function commit_smart_wallet_checker(address addr) external;

    function apply_smart_wallet_checker() external;

    function get_last_user_slope(address addr) external view returns (int128);

    function user_point_history__ts(address _addr, uint256 _idx) external view returns (uint256);

    function locked__end(address _addr) external view returns (uint256);

    function checkpoint() external;

    function deposit_for(address _addr, uint256 _value) external;

    function create_lock(uint256 _value, uint256 _unlock_time) external;

    function increase_amount(uint256 _value) external;

    function increase_unlock_time(uint256 _unlock_time) external;

    function withdraw() external;

    function balanceOf(address addr) external view returns (uint256);

    function balanceOf(address addr, uint256 _t) external view returns (uint256);

    function balanceOfAt(address addr, uint256 _block) external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function totalSupply(uint256 t) external view returns (uint256);

    function totalSupplyAt(uint256 _block) external view returns (uint256);

    function changeController(address _newController) external;

    function token() external view returns (address);

    function supply() external view returns (uint256);

    function locked(address arg0) external view returns (int128 amount, uint256 end);

    function epoch() external view returns (uint256);

    function point_history(uint256 arg0) external view returns (int128 bias, int128 slope, uint256 ts, uint256 blk);

    function user_point_history(address arg0, uint256 arg1) external view returns (int128 bias, int128 slope, uint256 ts, uint256 blk);

    function user_point_epoch(address arg0) external view returns (uint256);

    function slope_changes(uint256 arg0) external view returns (int128);

    function controller() external view returns (address);

    function transfersEnabled() external view returns (bool);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function version() external view returns (string memory);

    function decimals() external view returns (uint256);

    function future_smart_wallet_checker() external view returns (address);

    function smart_wallet_checker() external view returns (address);

    function admin() external view returns (address);

    function future_admin() external view returns (address);
}
