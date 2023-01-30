pragma solidity 0.8.16;
import "BoringSolidity/libraries/BoringERC20.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/CurvePool.sol";
import "interfaces/YearnVault.sol";
import "interfaces/TetherToken.sol";

contract ThreeCryptoSwapper {

    // Local variables
    IBentoBoxV1 public immutable degenBox;
    
    CurvePool public constant MIM3POOL = CurvePool(0x5a6A4D54456819380173272A5E8E9B9904BdF41B);
    CurvePool constant public threecrypto = CurvePool(0xD51a44d3FaE010294C616388b506AcdA1bfAAE46);
    YearnVault public constant y3Crypto = YearnVault(0x8078198Fc424986ae89Ce4a910Fc109587b6aBF3);
    TetherToken public constant TETHER = TetherToken(0xdAC17F958D2ee523a2206206994597C13D831ec7); 
    IERC20 public constant MIM = IERC20(0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3);

    constructor(IBentoBoxV1 degenBox_) public {
        degenBox = degenBox_;
        MIM.approve(address(MIM3POOL), type(uint256).max);
        TETHER.approve(address(MIM3POOL), type(uint256).max);
    }

    // Swaps to a flexible amount, from an exact input amount
    function swap(
        IERC20 fromToken,
        IERC20 toToken,
        address recipient,
        uint256 shareToMin,
        uint256 shareFrom
    ) public returns (uint256 extraShare, uint256 shareReturned) {

        (uint256 amountFrom, ) = degenBox.withdraw(y3Crypto, address(this), address(this), 0, shareFrom);
        
        amountFrom = y3Crypto.withdraw();
        
        threecrypto.remove_liquidity_one_coin(amountFrom, 0, 0);
        
        uint256 amountIntermediate = TETHER.balanceOf(address(this));
        
        uint256 amountTo = MIM3POOL.exchange_underlying(3, 0, amountIntermediate, 0, address(degenBox));
        
        (, shareReturned) = degenBox.deposit(MIM, address(degenBox), recipient, amountTo, 0);
        extraShare = shareReturned - shareToMin;
    }

}