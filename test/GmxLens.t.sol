// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "src/lenses/GmxLens.sol";
import "script/GmxLens.s.sol";

contract GmxLensTest is BaseTest {
    GmxLens public lens;
    uint256 private constant PRICE_PRECISION = 10 ** 30;

    function setUp() public override {
        forkArbitrum(61053326);
        super.setUp();

        GmxLensScript script = new GmxLensScript();
        script.setTesting(true);
        (lens) = script.run();
    }

    function testGetTokenInfo() public {
        GmxLens.TokenInfo memory tokenInfo = lens.getTokenInfo(constants.getAddress("arbitrum.usdc"));
        assertEq(tokenInfo.weight, 39000);
        assertEq(tokenInfo.usdgAmount, 185984617523937510630298115);
    }

    function testGetGlpPrice() public {
        assertEq(lens.getGlpPrice(), 932904323002367531315615929505);
    }

    /* Burn GLP */
    function testGetTokenOutFromBurningGlpUsdc() public {
        address tokenIn = constants.getAddress("arbitrum.usdc");
        uint256 glpAmount = (1000000 * 1e18);
        (uint256 amount, uint256 feeBasisPoints) = lens.getTokenOutFromBurningGlp(tokenIn, glpAmount);
        assertEq(amount, 930758643059);
        assertEq(feeBasisPoints, 23);
    }

    function testGetTokenOutFromBurningGlpWeth() public {
        address tokenIn = constants.getAddress("arbitrum.weth");
        uint256 glpAmount = (1000000 * 1e18);
        (uint256 amount, uint256 feeBasisPoints) = lens.getTokenOutFromBurningGlp(tokenIn, glpAmount);
        assertEq(amount, 599409240209417907363);
        assertEq(feeBasisPoints, 36);
    }

    function testGetTokenOutFromBurningGlpDai() public {
        address tokenIn = constants.getAddress("arbitrum.dai");
        uint256 glpAmount = (1000000 * 1e18);
        (uint256 amount, uint256 feeBasisPoints) = lens.getTokenOutFromBurningGlp(tokenIn, glpAmount);
        assertEq(amount, 929825738736459718462273);
        assertEq(feeBasisPoints, 33);
    }

    /* Buy GLP */
    function testGetMintedGlpFromTokenInUsdc() public {
        address tokenIn = constants.getAddress("arbitrum.usdc");
        uint256 tokenAmount = (1000000 * 1e6);
        (uint256 expectedGlp, uint256 feeBasisPoints) = lens.getMintedGlpFromTokenIn(tokenIn, tokenAmount);
        assertEq(expectedGlp, 1069027096787790364726515);
        assertEq(feeBasisPoints, 27);
    }

    function testGetMintedGlpFromTokenInWeth() public {
        address tokenIn = constants.getAddress("arbitrum.weth");
        uint256 tokenAmount = (645 * 1e18);
        (uint256 expectedGlp, uint256 feeBasisPoints) = lens.getMintedGlpFromTokenIn(tokenIn, tokenAmount);
        assertEq(expectedGlp, 1070684613696945126759718);
        assertEq(feeBasisPoints, 14);
    }

    function testGetMintedGlpFromTokenInDai() public {
        address tokenIn = constants.getAddress("arbitrum.dai");
        uint256 tokenAmount = (1000000 * 1e18);
        (uint256 expectedGlp, uint256 feeBasisPoints) = lens.getMintedGlpFromTokenIn(tokenIn, tokenAmount);
        assertEq(expectedGlp, 1069777441686769060460305);
        assertEq(feeBasisPoints, 20);
    }
}
