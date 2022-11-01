// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import "BoringSolidity/BoringOwnable.sol";
import "OpenZeppelin/utils/Address.sol";
import "interfaces/ICauldronV4.sol";
import "interfaces/IBentoBoxV1.sol";

contract CauldronOwner is BoringOwnable {
    using BoringERC20 for IERC20;

    error ErrNotOperator(address operator);
    event LogOperatorChanged(address operator, bool enabled);
    event LogTreasuryChanged(address previous, address current);

    mapping(address => bool) public operators;

    address public treasury;

    modifier onlyOperators() {
        if (!operators[msg.sender]) {
            revert ErrNotOperator(msg.sender);
        }
        _;
    }

    constructor(address _treasury) {
        operators[msg.sender] = true;
        treasury = _treasury;

        emit LogOperatorChanged(msg.sender, true);
        emit LogTreasuryChanged(address(0), _treasury);
    }

    function setOperator(address operator, bool enabled) external onlyOwner {
        operators[operator] = true;
        emit LogOperatorChanged(operator, enabled);
    }

    function transferMasterContractOwnership(BoringOwnable masterContract, address newOwner) public onlyOwner {
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

    function withdrawToken(IERC20 token) public onlyOperators {
        token.safeTransfer(treasury, token.balanceOf(address(this)));
    }

    function withdrawFromBentoBox(IERC20 token, IBentoBoxV1 bentoBox, uint256 share) public onlyOperators {
        uint256 maxShare = bentoBox.balanceOf(token, address(this));
        if(share > maxShare) {
            share = maxShare;
        }

        bentoBox.withdraw(token, address(this), treasury, 0, share);
    }

    function setTreasury(address _treasury) external onlyOwner {
        emit LogTreasuryChanged(treasury, _treasury);
        treasury = _treasury;
    }

    /// low level execution for any other future added functions
    function execute(
        address to,
        uint256 value,
        bytes calldata data
    ) external onlyOwner returns (bool success, bytes memory result) {
        // solhint-disable-next-line avoid-low-level-calls
        (success, result) = to.call{value: value}(data);
    }
}
