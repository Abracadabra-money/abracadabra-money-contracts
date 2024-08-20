// SPDX-License-Identifier: MIT
// solhint-disable avoid-low-level-calls
pragma solidity >=0.8.0;

import {IERC20} from "@BoringSolidity/interfaces/IERC20.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {IBentoBoxLite} from "/interfaces/IBentoBoxV1.sol";
import {ISwapperV2} from "/interfaces/ISwapperV2.sol";

enum SwapKind {
    GIVEN_IN,
    GIVEN_OUT
}

struct SingleSwap {
    bytes32 poolId;
    SwapKind kind;
    address assetIn;
    address assetOut;
    uint256 amount;
    bytes userData;
}

struct FundManagement {
    address sender;
    bool fromInternalBalance;
    address payable recipient;
    bool toInternalBalance;
}

interface IBalancerSwaps {
    function swap(
        SingleSwap memory singleSwap,
        FundManagement memory funds,
        uint256 limit,
        uint256 deadline
    ) external payable returns (uint256 amountCalculated);
}

interface IBalancerQuery {
    function querySwap(SingleSwap memory singleSwap, FundManagement memory funds) external returns (uint256);
}

/// @notice token liquidation/deleverage swapper for tokens using Matcha/0x aggregator
contract SDEUSDSwapper is ISwapperV2 {
    using SafeTransferLib for address;

    error ErrSwapFailed();

    bytes32 public constant POOL_ID = 0x41fdbea2e52790c0a1dc374f07b628741f2e062d0002000000000000000006be;
    SwapKind public constant SWAP_KIND = SwapKind.GIVEN_IN;
    IBalancerSwaps public constant BALANCER_SWAPS = IBalancerSwaps(0x881D40237659C251811CEC9c364ef91dC08D300C);
    IBalancerQuery public constant BALANCER_QUERY = IBalancerQuery(0xE39B5e3B6D74016b2F6A9673D7d7493B6DF549d5);
    IBentoBoxLite public constant BOX = IBentoBoxLite(0xd96f48665a1410C0cd669A88898ecA36B9Fc2cce);
    address public constant SDEUSD = 0x5C5b196aBE0d54485975D1Ec29617D42D9198326;
    address public constant DEUSD = 0x15700B564Ca08D9439C58cA5053166E8317aa138;
    address public constant MIM = 0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3;

    constructor() {
        MIM.safeApprove(address(BOX), type(uint256).max);
    }

    function previewSDEUSDOut(uint256 amountSDEUSD) external returns (uint256) {
        return
            BALANCER_QUERY.querySwap(
                SingleSwap({poolId: POOL_ID, kind: SWAP_KIND, assetIn: SDEUSD, assetOut: DEUSD, amount: amountSDEUSD, userData: ""}),
                FundManagement({
                    sender: address(this),
                    fromInternalBalance: false,
                    recipient: payable(address(this)),
                    toInternalBalance: false
                })
            );
    }

    function swap(
        address,
        address,
        address recipient,
        uint256 shareToMin,
        uint256 shareFrom,
        bytes calldata data
    ) public override returns (uint256 extraShare, uint256 shareReturned) {
        (address to, bytes memory swapData) = abi.decode(data, (address, bytes));
        (uint256 sdeusdAmount, ) = BOX.withdraw(SDEUSD, address(this), address(this), 0, shareFrom);

        BALANCER_SWAPS.swap(
            SingleSwap({poolId: POOL_ID, kind: SWAP_KIND, assetIn: SDEUSD, assetOut: DEUSD, amount: sdeusdAmount, userData: ""}),
            FundManagement({
                sender: address(this),
                fromInternalBalance: false,
                recipient: payable(address(this)),
                toInternalBalance: false
            }),
            type(uint256).max,
            type(uint256).max
        );

        if (IERC20(DEUSD).allowance(address(this), to) != type(uint256).max) {
            DEUSD.safeApprove(to, type(uint256).max);
        }

        // DEUSD -> MIM
        (bool success, ) = to.call(swapData);
        if (!success) {
            revert ErrSwapFailed();
        }

        // Refund remaining balance to the recipient
        uint256 balance = DEUSD.balanceOf(address(this));
        if (balance > 0) {
            DEUSD.safeTransfer(recipient, balance);
        }

        (, shareReturned) = BOX.deposit(MIM, address(this), recipient, MIM.balanceOf(address(this)), 0);
        extraShare = shareReturned - shareToMin;
    }
}
