// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {RebaseLibrary, Rebase} from "BoringSolidity/libraries/BoringRebase.sol";
import {ISwapperV2} from "interfaces/ISwapperV2.sol";
import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {IBentoBoxV1} from "interfaces/IBentoBoxV1.sol";
import {CauldronV4} from "cauldrons/CauldronV4.sol";
import {BoringMath, BoringMath128} from "BoringSolidity/libraries/BoringMath.sol";
import {ICauldronV4GmxV2} from "interfaces/ICauldronV4GmxV2.sol";
import {GmRouterOrderParams, IGmRouterOrder, IGmCauldronOrderAgent} from "periphery/GmxV2CauldronOrderAgent.sol";

/// @notice Cauldron with both whitelisting and checkpointing token rewards on add/remove/liquidate collateral
contract GmxV2CauldronV4 is CauldronV4 {
    using BoringMath for uint256;
    using BoringMath128 for uint128;
    using RebaseLibrary for Rebase;

    event LogOrderAgentChanged(address indexed previous, address indexed current);
    event LogOrderCreated(address indexed user, address indexed order);
    event LogWithdrawFromOrder(address indexed user, address indexed token, address indexed to, uint256 amount, bool close);
    event LogOrderCanceled(address indexed user, address indexed order);

    error ErrOrderAlreadyExists();
    error ErrOrderDoesNotExist();
    error ErrOrderNotFromUser();
    error ErrWhitelistedBorrowExceeded();

    // ACTION no < 10 to ensure ACCRUE is triggered
    uint8 public constant ACTION_WITHDRAW_FROM_ORDER = 9;

    uint8 public constant ACTION_CREATE_ORDER = 3;
    uint8 public constant ACTION_CANCEL_ORDER = ACTION_CUSTOM_START_INDEX + 2;

    IGmCauldronOrderAgent public orderAgent;
    mapping(address => IGmRouterOrder) public orders;

    constructor(IBentoBoxV1 box, IERC20 mim) CauldronV4(box, mim) {}

    function setOrderAgent(IGmCauldronOrderAgent _orderAgent) public onlyMasterContractOwner {
        emit LogOrderAgentChanged(address(orderAgent), address(_orderAgent));
        orderAgent = _orderAgent;
    }

    /// @notice Concrete implementation of `isSolvent`. Includes a second parameter to allow caching `exchangeRate`.
    /// @param _exchangeRate The exchange rate. Used to cache the `exchangeRate` between calls.
    function _isSolvent(address user, uint256 _exchangeRate) internal view override returns (bool) {
        // accrue must have already been called!
        uint256 borrowPart = userBorrowPart[user];
        if (borrowPart == 0) return true;
        uint256 collateralShare = userCollateralShare[user];
        if (collateralShare == 0 && orders[user] == IGmRouterOrder(address(0))) return false;

        Rebase memory _totalBorrow = totalBorrow;

        uint256 amountToAdd;

        if (orders[user] != IGmRouterOrder(address(0))) {
            amountToAdd = orders[user].orderValueInCollateral();
        }

        return
            bentoBox
                .toAmount(collateral, collateralShare, false)
                .add(amountToAdd)
                .mul(EXCHANGE_RATE_PRECISION / COLLATERIZATION_RATE_PRECISION)
                .mul(COLLATERIZATION_RATE) >=
            // Moved exchangeRate here instead of dividing the other side to preserve more precision
            borrowPart.mul(_totalBorrow.elastic).mul(_exchangeRate) / _totalBorrow.base;
    }

    function _additionalCookAction(
        uint8 action,
        CookStatus memory status,
        uint256 value,
        bytes memory data,
        uint256,
        uint256
    ) internal virtual override returns (bytes memory, uint8, CookStatus memory) {
        if (action == ACTION_WITHDRAW_FROM_ORDER) {
            (address token, address to, uint256 amount, bool close) = abi.decode(data, (address, address, uint256, bool));

            if (orders[msg.sender] == IGmRouterOrder(address(0))) {
                revert ErrOrderDoesNotExist();
            }
            orders[msg.sender].withdrawFromOrder(token, to, amount, close);
            status.needsSolvencyCheck = true;
            emit LogWithdrawFromOrder(msg.sender, token, to, amount, close);
        } else if (action == ACTION_CREATE_ORDER) {
            if (orders[msg.sender] != IGmRouterOrder(address(0))) {
                revert ErrOrderAlreadyExists();
            }
            GmRouterOrderParams memory params = abi.decode(data, (GmRouterOrderParams));
            orders[msg.sender] = IGmRouterOrder(orderAgent.createOrder{value: value}(msg.sender, params));
            blacklistedCallees[address(orders[msg.sender])] = true;
            status.needsSolvencyCheck = true;
            emit LogChangeBlacklistedCallee(address(orders[msg.sender]), true);
            emit LogOrderCreated(msg.sender, address(orders[msg.sender]));
        } else if (action == ACTION_CANCEL_ORDER) {
            if (orders[msg.sender] == IGmRouterOrder(address(0))) {
                revert ErrOrderDoesNotExist();
            }
            orders[msg.sender].cancelOrder();
            emit LogOrderCanceled(msg.sender, address(orders[msg.sender]));
        }

        return ("", 0, status);
    }

    /// @notice Handles the liquidation of users' balances, once the users' amount of collateral is too low.
    /// @param users An array of user addresses.
    /// @param maxBorrowParts A one-to-one mapping to `users`, contains maximum (partial) borrow amounts (to liquidate) of the respective user.
    /// @param to Address of the receiver in open liquidations if `swapper` is zero.
    function liquidate(
        address[] memory users,
        uint256[] memory maxBorrowParts,
        address to,
        ISwapperV2 swapper,
        bytes memory swapperData
    ) public virtual override {
        // Oracle can fail but we still need to allow liquidations
        (, uint256 _exchangeRate) = updateExchangeRate();
        accrue();

        uint256 allCollateralShare;
        uint256 allBorrowAmount;
        uint256 allBorrowPart;
        Rebase memory bentoBoxTotals = bentoBox.totals(collateral);
        _beforeUsersLiquidated(users, maxBorrowParts);

        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            if (!_isSolvent(user, _exchangeRate)) {
                // the user has an active order, cancel it before allowing liquidation
                if (orders[user] != IGmRouterOrder(address(0)) && orders[user].isActive()) {
                    orders[user].cancelOrder();
                    emit LogOrderCanceled(user, address(orders[user]));
                }
                uint256 borrowPart;
                uint256 availableBorrowPart = userBorrowPart[user];
                borrowPart = maxBorrowParts[i] > availableBorrowPart ? availableBorrowPart : maxBorrowParts[i];

                uint256 borrowAmount = totalBorrow.toElastic(borrowPart, false);
                uint256 collateralShare = bentoBoxTotals.toBase(
                    borrowAmount.mul(LIQUIDATION_MULTIPLIER).mul(_exchangeRate) /
                        (LIQUIDATION_MULTIPLIER_PRECISION * EXCHANGE_RATE_PRECISION),
                    false
                );

                _beforeUserLiquidated(user, borrowPart, borrowAmount, collateralShare);
                userBorrowPart[user] = availableBorrowPart.sub(borrowPart);
                if (collateralShare > userCollateralShare[user] && orders[user] != IGmRouterOrder(address(0))) {
                    orders[user].sendValueInCollateral(to, collateralShare - userCollateralShare[user]);
                    collateralShare = userCollateralShare[user];
                }

                userCollateralShare[user] = userCollateralShare[user].sub(collateralShare);
                _afterUserLiquidated(user, collateralShare);

                emit LogRemoveCollateral(user, to, collateralShare);
                emit LogRepay(msg.sender, user, borrowAmount, borrowPart);
                emit LogLiquidation(msg.sender, user, to, collateralShare, borrowAmount, borrowPart);

                // Keep totals
                allCollateralShare = allCollateralShare.add(collateralShare);
                allBorrowAmount = allBorrowAmount.add(borrowAmount);
                allBorrowPart = allBorrowPart.add(borrowPart);
            }
        }

        require(allBorrowAmount != 0, "Cauldron: all are solvent");
        totalBorrow.elastic = totalBorrow.elastic.sub(allBorrowAmount.to128());
        totalBorrow.base = totalBorrow.base.sub(allBorrowPart.to128());
        totalCollateralShare = totalCollateralShare.sub(allCollateralShare);
        // Apply a percentual fee share to sSpell holders
        {
            uint256 distributionAmount = (allBorrowAmount.mul(LIQUIDATION_MULTIPLIER) / LIQUIDATION_MULTIPLIER_PRECISION)
                .sub(allBorrowAmount)
                .mul(DISTRIBUTION_PART) / DISTRIBUTION_PRECISION; // Distribution Amount
            allBorrowAmount = allBorrowAmount.add(distributionAmount);
            accrueInfo.feesEarned = accrueInfo.feesEarned.add(distributionAmount.to128());
        }

        uint256 allBorrowShare = bentoBox.toShare(magicInternetMoney, allBorrowAmount, true);

        // Swap using a swapper freely chosen by the caller
        // Open (flash) liquidation: get proceeds first and provide the borrow after
        bentoBox.transfer(collateral, address(this), to, allCollateralShare);
        if (swapper != ISwapperV2(address(0))) {
            swapper.swap(address(collateral), address(magicInternetMoney), msg.sender, allBorrowShare, allCollateralShare, swapperData);
        }

        allBorrowShare = bentoBox.toShare(magicInternetMoney, allBorrowAmount, true);
        bentoBox.transfer(magicInternetMoney, msg.sender, address(this), allBorrowShare);
    }

    function closeOrder(address user) public {
        if (msg.sender != address(orders[user])) {
            revert ErrOrderNotFromUser();
        }
        blacklistedCallees[address(orders[user])] = false;
        orders[user] = IGmRouterOrder(address(0));
    }
}
