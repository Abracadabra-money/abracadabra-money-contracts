// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;
import "BoringSolidity/libraries/BoringERC20.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/ICurvePool.sol";
import "interfaces/IYearnVault.sol";
import "interfaces/ITetherToken.sol";

contract ThreeCryptoLevSwapper {
    using BoringERC20 for IERC20;

    // Local variables
    IBentoBoxV1 public immutable degenBox;
    ICurvePool public constant MIM3POOL = ICurvePool(0x5a6A4D54456819380173272A5E8E9B9904BdF41B);
    ITriCrypto public constant threecrypto = ITriCrypto(0xD51a44d3FaE010294C616388b506AcdA1bfAAE46);
    IYearnVault public constant y3Crypto = IYearnVault(0x8078198Fc424986ae89Ce4a910Fc109587b6aBF3);
    ITetherToken public constant TETHER = ITetherToken(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 public constant MIM = IERC20(0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3);
    IERC20 public constant CurveToken = IERC20(0xc4AD29ba4B3c580e6D59105FFf484999997675Ff);

    constructor(IBentoBoxV1 degenBox_) public {
        degenBox = degenBox_;
        MIM.approve(address(MIM3POOL), type(uint256).max);
        TETHER.approve(address(threecrypto), type(uint256).max);
        CurveToken.approve(address(y3Crypto), type(uint256).max);
    }

    // Swaps to a flexible amount, from an exact input amount
    function swap(
        address recipient,
        uint256 shareToMin,
        uint256 shareFrom
    ) public returns (uint256 extraShare, uint256 shareReturned) {
        (uint256 amountFrom, ) = degenBox.withdraw(MIM, address(this), address(this), 0, shareFrom);

        uint256 amountIntermediate = MIM3POOL.exchange_underlying(0, 3, amountFrom, 0, address(this));

        uint256[3] memory amountsAdded = [amountIntermediate, 0, 0];

        threecrypto.add_liquidity(amountsAdded, 0);

        uint256 amountTo = CurveToken.balanceOf(address(this));

        amountTo = y3Crypto.deposit(amountTo, address(degenBox));

        (, shareReturned) = degenBox.deposit(y3Crypto, address(degenBox), recipient, amountTo, 0);
        extraShare = shareReturned - shareToMin;
    }
}
