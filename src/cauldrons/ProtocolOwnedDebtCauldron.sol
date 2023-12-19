// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {RebaseLibrary, Rebase} from "BoringSolidity/libraries/BoringRebase.sol";
import {BoringERC20, IERC20} from "BoringSolidity/libraries/BoringERC20.sol";
import {BoringMath} from "BoringSolidity/libraries/BoringMath.sol";
import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {IOracle} from "interfaces/IOracle.sol";

contract ProtocolOwnedDebtCauldron {
    using RebaseLibrary for Rebase;
    using BoringMath for uint256;
    using BoringERC20 for IERC20;

    error ErrNotAllowed();
    event LogBorrow(address indexed from, address indexed to, uint256 amount, uint256 part);
    event LogRepay(address indexed from, address indexed to, uint256 amount, uint256 part);

    address public constant multisig = 0x5f0DeE98360d8200b20812e174d139A1a633EDd2;
    address public constant safe = 0xDF2C270f610Dc35d8fFDA5B453E74db5471E126B;
    IERC20 public constant magicInternetMoney = IERC20(0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3);
    address public immutable masterContract;
    IBentoBoxV1 public constant bentoBox = IBentoBoxV1(0xd96f48665a1410C0cd669A88898ecA36B9Fc2cce);

    /// @dev compatibility with Cauldron interface
    IERC20 public constant collateral = magicInternetMoney;
    IOracle public constant oracle = IOracle(address(0));
    bytes public constant oracleData = "";
    uint256 public constant totalCollateralShare = 0;
    mapping(address => uint256) public userCollateralShare;
    uint256 public constant exchangeRate = 0;

    mapping(address => uint256) public userBorrowPart;
    Rebase public totalBorrow;

    modifier onlySafe() {
        if (msg.sender != safe) {
            revert ErrNotAllowed();
        }
        _;
    }

    constructor() {
        masterContract = address(this);
    }

    function accrueInfo() external pure returns (uint64 /*lastAccrued*/, uint128 /*feesEarned*/, uint64 /*INTEREST_PER_SECOND*/) {
        return (0, 0, 0);
    }

    function borrow(uint256 amount) external onlySafe returns (uint256 part) {
        (totalBorrow, part) = totalBorrow.add(amount, false);
        userBorrowPart[safe] = userBorrowPart[safe].add(part);

        magicInternetMoney.safeTransferFrom(multisig, safe, amount);

        emit LogBorrow(safe, safe, amount, part);
    }

    function repay(uint256 part) external onlySafe returns (uint256 amount) {
        (totalBorrow, amount) = totalBorrow.sub(part, false);
        userBorrowPart[safe] = userBorrowPart[safe].sub(part);

        magicInternetMoney.safeTransferFrom(safe, multisig, amount);

        emit LogRepay(safe, safe, amount, part);
    }
}
