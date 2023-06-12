pragma solidity >=0.7.0 <0.9.0;

interface IYBribeV3 {
    event Blacklisted(address indexed user);
    event ChangeOwner(address owner);
    event ClearRewardRecipient(address indexed user, address recipient);
    event FeeUpdated(uint256 fee);
    event NewTokenReward(address indexed gauge, address indexed reward_token);
    event PeriodUpdated(address indexed gauge, uint256 indexed period, uint256 bias, uint256 blacklisted_bias);
    event RemovedFromBlacklist(address indexed user);
    event RewardAdded(address indexed briber, address indexed gauge, address indexed reward_token, uint256 amount, uint256 fee);
    event RewardClaimed(address indexed user, address indexed gauge, address indexed reward_token, uint256 amount);
    event SetRewardRecipient(address indexed user, address recipient);

    function _gauges_per_reward(address, uint256) external view returns (address);

    function _rewards_in_gauge(address, address) external view returns (bool);

    function _rewards_per_gauge(address, uint256) external view returns (address);

    function accept_owner() external;

    function active_period(address, address) external view returns (uint256);

    function add_reward_amount(address gauge, address reward_token, uint256 amount) external returns (bool);

    function add_to_blacklist(address _user) external;

    function claim_reward(address gauge, address reward_token) external returns (uint256);

    function claim_reward_for(address user, address gauge, address reward_token) external returns (uint256);

    function claim_reward_for_many(
        address[] memory _users,
        address[] memory _gauges,
        address[] memory _reward_tokens
    ) external returns (uint256[] memory amounts);

    function claimable(address user, address gauge, address reward_token) external view returns (uint256);

    function claims_per_gauge(address, address) external view returns (uint256);

    function clear_recipient() external;

    function current_period() external view returns (uint256);

    function fee_percent() external view returns (uint256);

    function fee_recipient() external view returns (address);

    function gauges_per_reward(address reward) external view returns (address[] memory);

    function get_blacklist() external view returns (address[] memory _blacklist);

    function get_blacklisted_bias(address gauge) external view returns (uint256);

    function is_blacklisted(address address_to_check) external view returns (bool);

    function last_user_claim(address, address, address) external view returns (uint256);

    function next_claim_time(address) external view returns (uint256);

    function owner() external view returns (address);

    function pending_owner() external view returns (address);

    function remove_from_blacklist(address _user) external;

    function reward_per_gauge(address, address) external view returns (uint256);

    function reward_per_token(address, address) external view returns (uint256);

    function reward_recipient(address) external view returns (address);

    function rewards_per_gauge(address gauge) external view returns (address[] memory);

    function set_fee_percent(uint256 _percent) external;

    function set_fee_recipient(address _recipient) external;

    function set_owner(address _new_owner) external;

    function set_recipient(address _recipient) external;
}
