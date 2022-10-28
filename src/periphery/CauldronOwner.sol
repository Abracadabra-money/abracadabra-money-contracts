// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import "BoringSolidity/BoringOwnable.sol";
import "OpenZeppelin/utils/Address.sol";
import "interfaces/ICauldronV4.sol";

contract CauldronOwner is BoringOwnable {
    error ErrNotOperator(address operator);

    event LogOperatorChanged(address operator, bool enabled);

    mapping(address => bool) public operators;

    modifier onlyOperators() {
        if (!operators[msg.sender]) {
            revert ErrNotOperator(msg.sender);
        }
        _;
    }

    constructor() {
        operators[msg.sender] = true;
    }

    function setOperator(address operator, bool enabled) external onlyOwner {
        operators[operator] = true;
        emit LogOperatorChanged(operator, enabled);
    }

    function transferMasterContractOwnership(BoringOwnable masterContract, address newOwner) public onlyOperators {
        masterContract.transferOwnership(newOwner, true, false);
    }

    function setFeeTo(ICauldronV2 cauldron, address newFeeTo) public onlyOperators {
        cauldron.setFeeTo(newFeeTo);
    }

    function reduceSupply(ICauldronV2 cauldron, uint256 amount) public onlyOperators {
        cauldron.reduceSupply(amount);
    }

    function changeInterestRate(ICauldronV3 cauldron, uint64 newInterestRate) public onlyOperators {
        cauldron.changeInterestRate(cauldron, newInterestRate);
    }

    function changeBorrowLimit(
        ICauldronV3 cauldron,
        uint128 newBorrowLimit,
        uint128 perAddressPart
    ) public onlyOperators {
        cauldron.changeBorrowLimit(newBorrowLimit, perAddressPart);
    }

    function setBlacklistedCallee(
        ICauldronV4 cauldron,
        address callee,
        bool blacklisted
    ) public onlyOperators {
        cauldron.setBlacklistedCallee(callee, blacklisted);
    }

    function setAllowedSupplyReducer(
        ICauldronV4 cauldron,
        address account,
        bool allowed
    ) public onlyOperators {
        cauldron.setAllowedSupplyReducer(account, allowed);
    }

    /// low level execution for any other future added functions
    function execute(
        address to,
        uint256 value,
        bytes calldata data
    ) external onlyOperators returns (bool success, bytes memory result) {
        // solhint-disable-next-line avoid-low-level-calls
        (success, result) = to.call{value: value}(data);
    }
}
