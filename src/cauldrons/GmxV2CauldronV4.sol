// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "BoringSolidity/libraries/BoringRebase.sol";
import "cauldrons/CauldronV4.sol";
import "libraries/compat/BoringMath.sol";

interface IMagicGmRouterOrder {
    function claim() external;

    function init(bytes memory) external payable;

    /// @notice cancelling an order
    function cancelOrder() external;
    
    /// @notice withdraw from an order that does not end in addition of collateral.
    function withdrawFromOrder(address token, address to, uint256 amount) external;

    /// @notice the value of the order in collateral terms
    function orderValueInCollateral() external view returns (uint256);
}

struct MagicGmRouterOrderParams {
    IOracle oracle;
    uint256 inputAmount;
    IERC20 inputToken;
    address market;
    uint256 executionFee;
    uint256 minOutput;
    bool deposit;
}
interface IGmxV2CauldronOrderAgent {
    function createOrder(address user, MagicGmRouterOrderParams memory params) external returns (IMagicGmRouterOrder);
}

/// @notice Cauldron with both whitelisting and checkpointing token rewards on add/remove/liquidate collateral
abstract contract GmxV2CauldronV4 is CauldronV4 {
    using BoringMath for uint256;
    using BoringMath128 for uint128;
    using RebaseLibrary for Rebase;

    error ErrWhitelistedBorrowExceeded();

    // ACTION no < 10 to ensure ACCRUE is triggered
    uint8 public constant ACTION_WITHDRAW_FROM_ORDER = 9;

    uint8 public constant ACTION_CREATE_ORDER = ACTION_CUSTOM_START_INDEX + 1;
    uint8 public constant ACTION_CANCEL_ORDER = ACTION_CUSTOM_START_INDEX + 2;

    IGmxV2CauldronOrderAgent public orderAgent;

    mapping(address => IMagicGmRouterOrder) orders;

    constructor(IBentoBoxV1 box, IERC20 mim) CauldronV4(box, mim) {}

    function setOrderAgent(IGmxV2CauldronOrderAgent agent) public onlyMasterContractOwner {
        orderAgent = agent;
    }

    /// @notice Concrete implementation of `isSolvent`. Includes a third parameter to allow caching `exchangeRate`.
    /// @param _exchangeRate The exchange rate. Used to cache the `exchangeRate` between calls.
    function _isSolvent(address user, uint256 _exchangeRate) override internal view returns (bool) {
        // accrue must have already been called!
        uint256 borrowPart = userBorrowPart[user];
        if (borrowPart == 0) return true;
        uint256 collateralShare = userCollateralShare[user];
        if (collateralShare == 0) return false;

        Rebase memory _totalBorrow = totalBorrow;

        uint256 amountToAdd;

        if(orders[user] != IMagicGmRouterOrder(address(0))) {
            //uint256 marketTokenFromValue = orders[user].orderValueUSD() * _exchangeRate / EXCHANGE_RATE_PRECISION;
            //uint256 minMarketTokens = orders[user].marketTokens();
            amountToAdd = orders[user].orderValueInCollateral(); //minMarketTokens < marketTokenFromValue ? minMarketTokens : marketTokenFromValue;
        }

        return
            (bentoBox.toAmount(
                collateral,
                collateralShare.mul(EXCHANGE_RATE_PRECISION / COLLATERIZATION_RATE_PRECISION).mul(COLLATERIZATION_RATE),
                false
            ) + amountToAdd * EXCHANGE_RATE_PRECISION) >=
            // Moved exchangeRate here instead of dividing the other side to preserve more precision
            borrowPart.mul(_totalBorrow.elastic).mul(_exchangeRate) / _totalBorrow.base;
    }

    function _additionalCookAction(
        uint8 action,
        CookStatus memory status,
        uint256,
        bytes memory data,
        uint256,
        uint256
    ) internal virtual override returns (bytes memory, uint8, CookStatus memory) {
        if (action == ACTION_WITHDRAW_FROM_ORDER) {
            (address token, address to, uint256 amount) = abi.decode(data, (address, address, uint256));
            orders[msg.sender].withdrawFromOrder(token, to, amount);
            status.needsSolvencyCheck = true;
        }

        if (action == ACTION_CREATE_ORDER) {
            require(orders[msg.sender] == IMagicGmRouterOrder(address(0)), "active order");
            (MagicGmRouterOrderParams memory params) = abi.decode(data, (MagicGmRouterOrderParams));
            orders[msg.sender] = orderAgent.createOrder(msg.sender, params);
        }

        if (action == ACTION_CANCEL_ORDER) {
            require(orders[msg.sender] != IMagicGmRouterOrder(address(0)), "no active order");
            orders[msg.sender].cancelOrder();
        }

        return ("", 0, status);
    }

    function closeOrder(address user) public {
        require(msg.sender == address(orders[user]), "Not from order");
        orders[user] = IMagicGmRouterOrder(address(0));
    }
}
