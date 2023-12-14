// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ERC20} from "BoringSolidity/ERC20.sol";
import {BoringOwnable} from "BoringSolidity/BoringOwnable.sol";
import {ICauldronV2} from "interfaces/ICauldronV2.sol";
import {ICauldronV3} from "interfaces/ICauldronV3.sol";
import {ICauldronV4} from "interfaces/ICauldronV4.sol";
import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";

contract CauldronOwner is BoringOwnable {
    error ErrNotOperator(address operator);
    error ErrNotDeprecated(address cauldron);
    error ErrNotMasterContract(address cauldron);

    event LogOperatorChanged(address indexed operator, bool previous, bool current);
    event LogTreasuryChanged(address indexed previous, address indexed current);
    event LogDeprecated(address indexed cauldron, bool previous, bool current);

    ERC20 public immutable mim;

    mapping(address => bool) public operators;
    mapping(address => bool) public deprecated;

    address public treasury;

    modifier onlyOperators() {
        if (msg.sender != owner && !operators[msg.sender]) {
            revert ErrNotOperator(msg.sender);
        }
        _;
    }

    constructor(address _treasury, ERC20 _mim) {
        treasury = _treasury;
        mim = _mim;

        emit LogTreasuryChanged(address(0), _treasury);
    }

    function reduceSupply(ICauldronV2 cauldron, uint256 amount) external onlyOperators {
        cauldron.reduceSupply(amount);
    }

    function changeInterestRate(ICauldronV3 cauldron, uint64 newInterestRate) external onlyOperators {
        cauldron.changeInterestRate(newInterestRate);
    }

    function reduceCompletely(ICauldronV2 cauldron) external {
        if (!deprecated[address(cauldron)]) {
            revert ErrNotDeprecated(address(cauldron));
        }

        IBentoBoxV1 bentoBox = IBentoBoxV1(cauldron.bentoBox());
        uint256 amount = bentoBox.toAmount(mim, bentoBox.balanceOf(mim, address(cauldron)), false);
        cauldron.reduceSupply(amount);
    }

    function changeBorrowLimit(ICauldronV3 cauldron, uint128 newBorrowLimit, uint128 perAddressPart) external onlyOperators {
        cauldron.changeBorrowLimit(newBorrowLimit, perAddressPart);
    }

    function withdrawMIMToTreasury(IBentoBoxV1 bentoBox, uint256 share) external onlyOperators {
        uint256 maxShare = bentoBox.balanceOf(mim, address(this));
        if (share > maxShare) {
            share = maxShare;
        }

        bentoBox.withdraw(mim, address(this), treasury, 0, share);
    }

    function setFeeTo(ICauldronV2 cauldron, address newFeeTo) external onlyOperators {
        if (cauldron.masterContract() != cauldron) {
            revert ErrNotMasterContract(address(cauldron));
        }

        cauldron.setFeeTo(newFeeTo);
    }

    function setDeprecated(address cauldron, bool _deprecated) external onlyOperators {
        emit LogDeprecated(cauldron, deprecated[cauldron], _deprecated);

        deprecated[cauldron] = _deprecated;
    }

    function setBlacklistedCallee(ICauldronV4 cauldron, address callee, bool blacklisted) external onlyOperators {
        cauldron.setBlacklistedCallee(callee, blacklisted);
    }

    function setOperator(address operator, bool enabled) external onlyOwner {
        emit LogOperatorChanged(operator, operators[operator], enabled);
        operators[operator] = enabled;
    }

    function setTreasury(address _treasury) external onlyOwner {
        emit LogTreasuryChanged(treasury, _treasury);
        treasury = _treasury;
    }

    function transferMasterContractOwnership(BoringOwnable masterContract, address newOwner) external onlyOwner {
        masterContract.transferOwnership(newOwner, true, false);
    }

    function rescueMIM() external {
        mim.transfer(treasury, mim.balanceOf(address(this)));
    }

    /// low level execution for any other future added functions
    function execute(address to, uint256 value, bytes calldata data) external onlyOwner returns (bool success, bytes memory result) {
        // solhint-disable-next-line avoid-low-level-calls
        (success, result) = to.call{value: value}(data);
    }
}
