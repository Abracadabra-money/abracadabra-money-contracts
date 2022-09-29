// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/BoringOwnable.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import "tokens/ERC20Vault.sol";
import "interfaces/IGmxRewardRouterV2.sol";

contract GlpWrapperUserDepositMasterContract {
    error NotWrapper();

    uint8 public constant decimals = 18;

    GlpWrapper private immutable wrapper;

    modifier onlyWrapper() {
        if (msg.sender != address(wrapper)) {
            revert NotWrapper();
        }
        _;
    }

    constructor(GlpWrapper _wrapper) {
        wrapper = _wrapper;
    }
}

contract GlpWrapper is IERC20, BoringOwnable {
    using BoringERC20 for IERC20;

    event RewardRouterChanged(IGmxRewardRouterV2 previous, IGmxRewardRouterV2 current);

    IERC20 public immutable fsGLP;
    GlpWrapperUserDepositMasterContract public immutable userDepositMasterContract;

    uint256 public override totalSupply;
    IGmxRewardRouterV2 public rewardRouter;

    constructor(IERC20 _fsGLP) {
        fsGLP = _fsGLP;
        userDepositMasterContract = new GlpWrapperUserDepositMasterContract(this);
    }

    function name() external pure returns (string memory) {
        return "Abracadabra wrappedGLP";
    }

    function symbol() external pure returns (string memory) {
        return "abraWrappedGLP";
    }

    function _mint(address user, uint256 amount) internal {
        uint256 newTotalSupply = totalSupply + amount;
        require(newTotalSupply >= totalSupply, "Mint overflow");
        totalSupply = newTotalSupply;
        balanceOf[user] += amount;
        emit Transfer(address(0), user, amount);
    }

    function _burn(address user, uint256 amount) internal {
        require(balanceOf[user] >= amount, "Burn too much");
        totalSupply -= amount;
        balanceOf[user] -= amount;
        emit Transfer(user, address(0), amount);
    }

    function balanceOf(address _owner) external view returns (uint256 balance);

    function transfer(address _to, uint256 _value) external returns (bool success);

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool success);

    function approve(address _spender, uint256 _value) external returns (bool success);

    function allowance(address _owner, address _spender) external view returns (uint256 remaining);

    /// @notice EIP 2612
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {}

    function setRewardRouter(IGmxRewardRouterV2 router) external onlyOwner {
        emit RewardRouterChanged(rewardRouter, router);
        rewardRouter = router;
    }

    /*function mintAndStakeGlp(
        address _token,
        uint256 _amount,
        uint256 _minUsdg,
        uint256 _minGlp
    ) external returns (uint256);

    function mintAndStakeGlpETH(uint256 _minUsdg, uint256 _minGlp) external payable returns (uint256);*/
}
