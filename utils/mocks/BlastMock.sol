// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Vm} from "forge-std/Vm.sol";
import {Toolkit, getToolkit, ChainId} from "../Toolkit.sol";
import {IBlast, IBlastPoints, YieldMode, GasMode, IERC20Rebasing} from "interfaces/IBlast.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {WETH} from "solady/tokens/WETH.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

abstract contract BlastTokenMock is IERC20Rebasing {
    event Configure(address indexed account, YieldMode yieldMode);
    event Claim(address indexed account, address indexed recipient, uint256 amount);

    error CannotClaimToSameAccount();
    error NotClaimableAccount();

    mapping(address => YieldMode) private _yieldMode;
    mapping(address account => uint256 amount) claimable;

    function configure(YieldMode newYieldMode) external returns (uint256) {
        _yieldMode[msg.sender] = newYieldMode;
        return _balanceOf(msg.sender);
    }

    function addClaimable(address account, uint256 amount) external {
        claimable[account] += amount;
    }

    function getConfiguration(address account) public view returns (YieldMode) {
        return _yieldMode[account];
    }

    function claim(address recipient, uint256 amount) external returns (uint256) {
        address account = msg.sender;

        if (account == recipient) {
            revert CannotClaimToSameAccount();
        }

        if (getConfiguration(account) != YieldMode.CLAIMABLE) {
            revert NotClaimableAccount();
        }

        emit Claim(msg.sender, recipient, amount);

        claimable[account] -= amount;
        _claim(recipient, amount);

        return amount;
    }

    function getClaimableAmount(address account) external view returns (uint256) {
        if (getConfiguration(account) != YieldMode.CLAIMABLE) {
            revert NotClaimableAccount();
        }

        return claimable[account];
    }

    function _claim(address account, uint256 amount) internal virtual;

    function _balanceOf(address account) internal virtual returns (uint256);
}

contract BlastToken is ERC20, BlastTokenMock {
    constructor(uint8 decimals_) ERC20("BlastToken", "BLAST", decimals_) {}

    function _claim(address account, uint256 amount) internal override {
        super._mint(account, amount);
    }

    function _balanceOf(address account) internal view override returns (uint256) {
        return balanceOf[account];
    }
}

contract BlastWETH is WETH, BlastTokenMock {
    Vm constant vm = Vm(address(bytes20(uint160(uint256(keccak256("hevm cheat code"))))));

    function _claim(address account, uint256 amount) internal override {
        vm.deal(address(this), amount);
        this.deposit{value: amount}();
        transfer(account, amount);
    }

    function _balanceOf(address account) internal view override returns (uint256) {
        return balanceOf(account);
    }
}

contract BlastPointsMock is IBlastPoints {
    function configurePointsOperator(address) external override {}
}

/// @title BlastMock
/// @notice Mock contract for Blast L2, only supports claimable mode.
contract BlastMock is IBlast {
    using SafeTransferLib for address;

    error NotClaimableAccount();

    Vm constant vm = Vm(address(bytes20(uint160(uint256(keccak256("hevm cheat code"))))));
    Toolkit internal toolkit = getToolkit();

    mapping(IERC20Rebasing token => bool) tokenEnabled;
    mapping(address account => uint256 amount) claimableAmounts;
    mapping(address account => uint256 amount) claimableGas;
    mapping(address => address) public governorMap;
    mapping(address => YieldMode) private _yieldMode;
    mapping(address => GasMode) private _gasYieldMode;

    constructor() {}

    function enableYieldTokenMocks() public {
        _registerToken(0x4300000000000000000000000000000000000003, IERC20Rebasing(address(new BlastToken(6))));
        _registerToken(0x4300000000000000000000000000000000000004, IERC20Rebasing(address(new BlastWETH())));
    }

    function getConfiguration(address account) public view returns (YieldMode) {
        return _yieldMode[account];
    }

    function getGasConfiguration(address account) public view returns (GasMode) {
        return _gasYieldMode[account];
    }

    function _registerToken(address tokenAddress, IERC20Rebasing impl) internal {
        tokenEnabled[IERC20Rebasing(tokenAddress)] = true;
        vm.etch(tokenAddress, address(impl).code);
        vm.allowCheatcodes(tokenAddress);
    }

    function isGovernor(address contractAddress) public view returns (bool) {
        return msg.sender == governorMap[contractAddress];
    }

    function governorNotSet(address contractAddress) internal view returns (bool) {
        return governorMap[contractAddress] == address(0);
    }

    function isAuthorized(address contractAddress) public view returns (bool) {
        return isGovernor(contractAddress) || (governorNotSet(contractAddress) && msg.sender == contractAddress);
    }

    function configure(YieldMode yieldMode, GasMode gasMode, address governor) external {
        require(isAuthorized(msg.sender), "not authorized to configure contract");
        governorMap[msg.sender] = governor;
        _yieldMode[msg.sender] = yieldMode;
        _gasYieldMode[msg.sender] = gasMode;
    }

    function configureContract(address contractAddress, YieldMode yieldMode, GasMode gasMode, address _newGovernor) external {
        require(isAuthorized(contractAddress), "not authorized to configure contract");
        governorMap[contractAddress] = _newGovernor;
        _yieldMode[msg.sender] = yieldMode;
        _gasYieldMode[msg.sender] = gasMode;
    }

    function configureClaimableYield() external {
        require(isAuthorized(msg.sender), "not authorized to configure contract");
        _yieldMode[msg.sender] = YieldMode.CLAIMABLE;
    }

    function configureClaimableYieldOnBehalf(address contractAddress) external {
        require(isAuthorized(contractAddress), "not authorized to configure contract");
        _yieldMode[msg.sender] = YieldMode.CLAIMABLE;
    }

    function configureAutomaticYield() external {}

    function configureAutomaticYieldOnBehalf(address contractAddress) external {}

    function configureVoidYield() external {}

    function configureVoidYieldOnBehalf(address contractAddress) external {}

    function configureClaimableGas() external {
        require(isAuthorized(msg.sender), "not authorized to configure contract");
        _gasYieldMode[msg.sender] = GasMode.CLAIMABLE;
    }

    function configureClaimableGasOnBehalf(address contractAddress) external {
        require(isAuthorized(contractAddress), "not authorized to configure contract");
        _gasYieldMode[msg.sender] = GasMode.CLAIMABLE;
    }

    function configureVoidGas() external {}

    function configureVoidGasOnBehalf(address contractAddress) external {}

    function configureGovernor(address _governor) external {
        require(isAuthorized(msg.sender), "not authorized to configure contract");
        governorMap[msg.sender] = _governor;
    }

    function configureGovernorOnBehalf(address _newGovernor, address contractAddress) external {
        require(isAuthorized(contractAddress), "not authorized to configure contract");
        governorMap[contractAddress] = _newGovernor;
    }

    function readClaimableYield(address contractAddress) external view override returns (uint256) {
        return claimableAmounts[contractAddress];
    }

    function addClaimable(address account, uint256 amount) external {
        claimableAmounts[account] += amount;
        vm.deal(address(this), amount);
    }

    function addClaimableGas(address account, uint256 amount) external {
        claimableGas[account] += amount;
        vm.deal(address(this), amount);
    }

    function claimYield(address contractAddress, address recipient, uint256 amount) public override returns (uint256) {
        if (getConfiguration(contractAddress) != YieldMode.CLAIMABLE) {
            revert NotClaimableAccount();
        }

        require(isAuthorized(contractAddress), "Not authorized to claim yield");
        claimableAmounts[contractAddress] -= amount;
        recipient.safeTransferETH(amount);
        return amount;
    }

    function claimAllYield(address contractAddress, address recipientOfYield) external returns (uint256) {
        return claimYield(contractAddress, recipientOfYield, claimableAmounts[contractAddress]);
    }

    function claimGas(
        address contractAddress,
        address recipientOfGas,
        uint256 gasToClaim,
        uint256 /*gasSecondsToConsume*/
    ) public returns (uint256) {
        if (getGasConfiguration(contractAddress) != GasMode.CLAIMABLE) {
            revert NotClaimableAccount();
        }

        require(isAuthorized(contractAddress), "Not allowed to claim gas");
        claimableGas[contractAddress] -= gasToClaim;
        recipientOfGas.safeTransferETH(gasToClaim);
        return gasToClaim;
    }

    function claimAllGas(address contractAddress, address recipientOfGas) external returns (uint256) {
        return claimGas(contractAddress, recipientOfGas, claimableGas[contractAddress], 0);
    }

    function claimGasAtMinClaimRate(
        address contractAddress,
        address recipientOfGas,
        uint256 /*minClaimRateBips*/
    ) external returns (uint256) {
        return claimGas(contractAddress, recipientOfGas, claimableGas[contractAddress], 0);
    }

    function claimMaxGas(address contractAddress, address recipientOfGas) external returns (uint256) {
        return claimGas(contractAddress, recipientOfGas, claimableGas[contractAddress], 0);
    }

    function readYieldConfiguration(address /*contractAddress*/) external pure returns (uint8) {
        return uint8(YieldMode.CLAIMABLE);
    }

    function readGasParams(
        address /*contractAddress*/
    ) external pure returns (uint256 etherSeconds, uint256 etherBalance, uint256 lastUpdated, GasMode) {
        return (0, 0, 0, GasMode.CLAIMABLE);
    }
}
