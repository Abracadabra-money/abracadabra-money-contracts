// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {BoringOwnable} from "BoringSolidity/BoringOwnable.sol";
import {ERC20} from "BoringSolidity/ERC20.sol";
import {ICauldronV2} from "interfaces/ICauldronV2.sol";
import {ICauldronV3} from "interfaces/ICauldronV3.sol";
import {ICauldronV4} from "interfaces/ICauldronV4.sol";
import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {CauldronRegistry, CauldronInfo} from "periphery/CauldronRegistry.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";

contract CauldronOwner is OwnableRoles {
    error ErrNotOperator(address operator);
    error ErrNotDeprecated(address cauldron);
    error ErrNotMasterContract(address cauldron);

    event LogOperatorChanged(address indexed operator, bool previous, bool current);
    event LogTreasuryChanged(address indexed previous, address indexed current);
    event LogRegistryChanged(address indexed previous, address indexed current);
    event LogDeprecated(address indexed cauldron, bool previous, bool current);

    // ROLES
    uint256 public constant ROLE_OPERATOR = _ROLE_0;
    uint256 public constant ROLE_REDUCE_SUPPLY = _ROLE_1;
    uint256 public constant ROLE_CHANGE_INTEREST_RATE = _ROLE_2;
    uint256 public constant ROLE_CHANGE_BORROW_LIMIT = _ROLE_3;
    uint256 public constant ROLE_SET_BLACKLISTED_CALLEE = _ROLE_4;

    ERC20 public immutable mim;
    CauldronRegistry public registry;
    address public treasury;

    constructor(address _treasury, ERC20 _mim, address _owner) {
        treasury = _treasury;
        mim = _mim;

        _setOwner(_owner);
        emit LogTreasuryChanged(address(0), _treasury);
    }

    /////////////////////////////////////////////////////////////////////////////////
    // PERMISSIONLESS
    /////////////////////////////////////////////////////////////////////////////////

    function rescueMIM() external {
        mim.transfer(treasury, mim.balanceOf(address(this)));
    }

    /////////////////////////////////////////////////////////////////////////////////
    // ROLE BASED OPERATORS
    /////////////////////////////////////////////////////////////////////////////////

    function reduceSupply(ICauldronV2 cauldron, uint256 amount) external onlyOwnerOrRoles(ROLE_OPERATOR | ROLE_REDUCE_SUPPLY) {
        cauldron.reduceSupply(amount);
    }

    function reduceCompletely(ICauldronV2 cauldron) external onlyOwnerOrRoles(ROLE_OPERATOR | ROLE_REDUCE_SUPPLY) {
        if (!registry.isDeprecated(address(cauldron))) {
            revert ErrNotDeprecated(address(cauldron));
        }

        IBentoBoxV1 bentoBox = IBentoBoxV1(cauldron.bentoBox());
        uint256 amount = bentoBox.toAmount(mim, bentoBox.balanceOf(mim, address(cauldron)), false);
        cauldron.reduceSupply(amount);
    }

    function changeInterestRate(
        ICauldronV3 cauldron,
        uint64 newInterestRate
    ) external onlyOwnerOrRoles(ROLE_OPERATOR | ROLE_CHANGE_INTEREST_RATE) {
        cauldron.changeInterestRate(newInterestRate);
    }

    function changeBorrowLimit(
        ICauldronV3 cauldron,
        uint128 newBorrowLimit,
        uint128 perAddressPart
    ) external onlyOwnerOrRoles(ROLE_OPERATOR | ROLE_CHANGE_BORROW_LIMIT) {
        cauldron.changeBorrowLimit(newBorrowLimit, perAddressPart);
    }

    function setBlacklistedCallee(
        ICauldronV4 cauldron,
        address callee,
        bool blacklisted
    ) external onlyOwnerOrRoles(ROLE_OPERATOR | ROLE_SET_BLACKLISTED_CALLEE) {
        cauldron.setBlacklistedCallee(callee, blacklisted);
    }

    /////////////////////////////////////////////////////////////////////////////////
    // ADMIN
    /////////////////////////////////////////////////////////////////////////////////

    function setFeeTo(ICauldronV2 cauldron, address newFeeTo) external onlyOwner {
        if (cauldron.masterContract() != cauldron) {
            revert ErrNotMasterContract(address(cauldron));
        }

        cauldron.setFeeTo(newFeeTo);
    }

    function setTreasury(address _treasury) external onlyOwner {
        emit LogTreasuryChanged(treasury, _treasury);
        treasury = _treasury;
    }

    function setRegistry(CauldronRegistry _registry) external onlyOwner {
        emit LogRegistryChanged(address(registry), address(_registry));
        registry = _registry;
    }
    
    function transferMasterContractOwnership(BoringOwnable masterContract, address newOwner) external onlyOwner {
        masterContract.transferOwnership(newOwner, true, false);
    }

    function withdrawMIMToTreasury(IBentoBoxV1 bentoBox, uint256 share) external onlyOwner {
        uint256 maxShare = bentoBox.balanceOf(mim, address(this));
        if (share > maxShare) {
            share = maxShare;
        }

        bentoBox.withdraw(mim, address(this), treasury, 0, share);
    }

    /// low level execution for any other future added functions
    function execute(address to, uint256 value, bytes calldata data) external onlyOwner returns (bool success, bytes memory result) {
        // solhint-disable-next-line avoid-low-level-calls
        (success, result) = to.call{value: value}(data);
    }
}
