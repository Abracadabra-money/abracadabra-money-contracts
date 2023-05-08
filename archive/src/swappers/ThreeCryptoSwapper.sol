// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/libraries/BoringERC20.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/ICurvePool.sol";
import "interfaces/IYearnVault.sol";
import "interfaces/ITetherToken.sol";

contract ThreeCryptoSwapper {

    // Local variables
    IBentoBoxV1 public immutable degenBox;
    
    ICurvePool public constant MIM3POOL = ICurvePool(0x5a6A4D54456819380173272A5E8E9B9904BdF41B);
    ITriCrypto constant public threecrypto = ITriCrypto(0xD51a44d3FaE010294C616388b506AcdA1bfAAE46);
    IYearnVault public constant y3Crypto = IYearnVault(0x8078198Fc424986ae89Ce4a910Fc109587b6aBF3);
    ITetherToken public constant TETHER = ITetherToken(0xdAC17F958D2ee523a2206206994597C13D831ec7); 
    IERC20 public constant MIM = IERC20(0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3);

    constructor(IBentoBoxV1 degenBox_) {
        degenBox = degenBox_;
        MIM.approve(address(MIM3POOL), type(uint256).max);
        TETHER.approve(address(MIM3POOL), type(uint256).max);
    }

    // Swaps to a flexible amount, from an exact input amount
    function swap(
        IERC20,
        IERC20,
        address recipient,
        uint256 shareToMin,
        uint256 shareFrom
    ) public returns (uint256 extraShare, uint256 shareReturned) {

        (uint256 amountFrom, ) = degenBox.withdraw(y3Crypto, address(this), address(this), 0, shareFrom);
        
        amountFrom = y3Crypto.withdraw();
        
        threecrypto.remove_liquidity_one_coin(amountFrom, uint256(0), uint256(0));
        
        uint256 amountIntermediate = TETHER.balanceOf(address(this));
        
        uint256 amountTo = MIM3POOL.exchange_underlying(3, 0, amountIntermediate, 0, address(degenBox));
        
        (, shareReturned) = degenBox.deposit(MIM, address(degenBox), recipient, amountTo, 0);
        extraShare = shareReturned - shareToMin;
    }

}