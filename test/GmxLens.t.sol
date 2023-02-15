// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "src/lenses/GmxLens.sol";
import "script/GmxLens.s.sol";

contract GmxLensTest is BaseTest {
    GmxLens public lens;
    uint256 private constant PRICE_PRECISION = 10 ** 30;

    function setUp() public override {
        forkArbitrum(61007741);
        super.setUp();

        GmxLensScript script = new GmxLensScript();
        script.setTesting(true);
        (lens) = script.run();
    }

    function testGetMintedGlpFromTokenIn() public {
        address tokenIn = constants.getAddress("arbitrum.usdc");
        uint256 tokenAmount = (1000000 * 1e6);

        // Log the normal path.
        lens.getMintedGlpFromTokenIn(tokenIn, tokenAmount);

        IGmxGlpManager manager = IGmxGlpManager(0x3963FfC9dff443c2A94f21b129D429891E32ec18);
        IGmxVault vault = IGmxVault(0x489ee077994B6658eAfA855C308275EAd8097C4A);
        IERC20 usdg = IERC20(manager.usdg());

        uint256 price = vault.getMinPrice(tokenIn);

        uint256 usdgAmount = (tokenAmount * price) / PRICE_PRECISION;
        usdgAmount = vault.adjustForDecimals(usdgAmount, tokenIn, address(usdg));

        uint256 fee = lens._getFeeBasisPoints(
            usdgAmount,
            tokenIn,
            usdgAmount,
            vault.mintBurnFeeBasisPoints(),
            vault.taxBasisPoints(),
            true
        );
        assertEq(fee, 2700);
    }
}
