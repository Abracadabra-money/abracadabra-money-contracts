// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "BoringSolidity/libraries/BoringERC20.sol";
import "utils/BaseTest.sol";
import "script/GmxLens.s.sol";
import "lenses/GmxLens.sol";
import "interfaces/IGmxGlpRewardRouter.sol";

contract GmxLensTest is BaseTest {
    using BoringERC20 for IERC20;
    GmxLens lens;
    IVaultPriceFeed feed;

    struct TokenInfo {
        string name;
        IERC20 token;
        uint256 expectedMintedGlp;
        uint256 expectedTokenOut;
        uint256 expectedTokenOutPriceUsd;
        uint256 maxGlpBurningDeltaPercent;
    }

    TokenInfo[] tokenInfos;
    uint256[] maxGlpBurningDeltaPercent;

    function setUp() public override {}

    function xtestMintingAndBurning() public {
        forkArbitrum(61030822);
        super.setUp();

        GmxLensScript script = new GmxLensScript();
        script.setTesting(true);
        (lens) = script.run();

        feed = IVaultPriceFeed(0x2d68011bcA022ed0E474264145F46CC4de96a002);

        uint256 amountInUsd = 1_000_000 ether;
        IGmxVault vault = lens.vault();

        _addTokens();

        {
            //console2.log("=== getMintedGlpFromTokenIn ===");
            for (uint256 i = 0; i < tokenInfos.length; i++) {
                TokenInfo storage info = tokenInfos[i];

                //console2.log("");
                //console2.log(info.name);

                uint8 decimals = info.token.safeDecimals();
                uint256 price = vault.getMinPrice(address(info.token)) / 1e12; // 18 decimals
                uint256 tokenAmount = (amountInUsd * 10**decimals) / price;

                //console2.log("token amount", tokenAmount);
                (uint256 glpAmount, ) = lens.getMintedGlpFromTokenIn(address(info.token), tokenAmount);
                //console2.log("glp amount", glpAmount);
                assertEq(glpAmount, info.expectedMintedGlp);
            }
        }

        {
            //console2.log("=== getTokenOutFromBurningGlp ===");
            uint256 glpAmount = 1_000_000 ether;

            for (uint256 i = 0; i < tokenInfos.length; i++) {
                TokenInfo storage info = tokenInfos[i];

                //console2.log("");
                //console2.log(info.name);

                (uint256 tokenOut, ) = lens.getTokenOutFromBurningGlp(address(info.token), glpAmount);

                assertEq(tokenOut, info.expectedTokenOut);
                //console2.log("amount out", tokenOut);

                uint8 decimals = info.token.safeDecimals();
                uint256 price = IVaultPriceFeed(vault.priceFeed()).getPrimaryPrice(address(info.token), false) / 1e12; // 18 decimals

                uint256 valueInUsd = (tokenOut * price) / 10**decimals / 1e18;
                assertEq(valueInUsd, info.expectedTokenOutPriceUsd);
                //console2.log("value $", valueInUsd);
            }
        }
    }

    function xtestMintingBurningAccuracy() public {
        uint256 passCount = 3;
        uint256 glpAmount = 2_000_000 ether;

        forkArbitrum(65501218);
        super.setUp();

        address whale = 0x85667409a723684Fe1e57Dd1ABDe8D88C2f54214;

        lens = GmxLens(0xe121904194eB69e5b589b58EDCbc5B74069787C3);

        pushPrank(whale);
        _addTokens();

        IGmxGlpRewardRouter glpRewardRouter = IGmxGlpRewardRouter(0xB95DB5B167D75e6d04227CfFFA61069348d271F5);
        IERC20 sGLP = IERC20(0x5402B5F40310bDED796c7D0F3FF6683f5C0cFfdf);

        //console2.log("Starting glp amount", glpAmount);

        for (uint256 passNo; passNo < passCount; passNo++) {
            //console2.log("Pass", passNo + 1, "/", passCount);

            for (uint256 i = 0; i < tokenInfos.length; i++) {
                //console2.log("___");

                TokenInfo storage info = tokenInfos[i];
                //console2.log(info.name);

                uint256 balanceTokenBefore = info.token.balanceOf(whale);
                uint256 sGLpAmountBefore = sGLP.balanceOf(whale);
                (uint256 tokenOut, ) = lens.getTokenOutFromBurningGlp(address(info.token), glpAmount);
                //console2.log("Expecting Token In", info.name, tokenOut);
                glpRewardRouter.unstakeAndRedeemGlp(address(info.token), glpAmount, 0, whale);

                uint256 balanceTokenAfter = info.token.balanceOf(whale);
                uint256 sGLpAmountAfter = sGLP.balanceOf(whale);

                assertGe(balanceTokenAfter, balanceTokenBefore);

                assertApproxEqRel(balanceTokenAfter - balanceTokenBefore, tokenOut, info.maxGlpBurningDeltaPercent);

                assertEq(sGLpAmountBefore - sGLpAmountAfter, glpAmount);

                uint256 tokenAmount = balanceTokenAfter;
                balanceTokenBefore = balanceTokenAfter;
                sGLpAmountBefore = sGLpAmountAfter;

                (glpAmount, ) = lens.getMintedGlpFromTokenIn(address(info.token), tokenAmount);
                //console2.log("Expecting GLP out", glpAmount, "from", info.name);
                info.token.approve(address(glpRewardRouter.glpManager()), balanceTokenBefore);

                assertEq(sGLP.balanceOf(address(this)), 0);
                glpRewardRouter.mintAndStakeGlp(address(info.token), balanceTokenBefore, 0, 0);

                sGLpAmountAfter = sGLP.balanceOf(whale);
                balanceTokenAfter = info.token.balanceOf(whale);

                assertEq(balanceTokenAfter, 0);
                assertEq(sGLpAmountAfter - sGLpAmountBefore, glpAmount);
                //console2.log("___");
            }
        }

        popPrank();
    }

    /**
        GMX Stats at block 66172459
        ------------------------------------------------
        GLP price: $0.9492

        Fees when burning 1M GLP:
        | TOKEN | PRICE      | AVAILABLE       | FEES  |
        | ------| -------    |-------          |-------|
        | ETH   | $1,645.50	 | $126,116,306.22 | 0.31% |
        | USDC  | $1.00	     | $112,859,840.65 | 0.27% |
        | USDT  | $1.00	     | $5,272,915.81   | 0.41% |
        | BTC   | $23,473.56 | $91,136,774.89  | 0.11% | BEST
        | LINK  | $7.24 	 | $4,721,561.63   | 0.38% |
        | UNI   | $6.61	     | $2,569,008.11   | 0.59% |
        | DAI   | $1.00	     | $22,329,002.01  | 0.21% |
        | FRAX  | $1.00	     | $8,520,524.53   | 0.39% |
    */
    function testBurningWithParts() public {
        forkArbitrum(66172459);
        super.setUp();

        GmxLensScript script = new GmxLensScript();
        script.setTesting(true);
        (lens) = script.run();

        address[] memory tokens = new address[](8);
        tokens[0] = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; // WETH
        tokens[1] = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8; // USDC
        tokens[2] = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9; // USDT
        tokens[3] = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f; // WBTC
        tokens[4] = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4; // LINK
        tokens[5] = 0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0; // UNI
        tokens[6] = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1; // DAI
        tokens[7] = 0x17FC002b466eEc40DaE837Fc4bE5c67993ddBd6F; // FRAX

        {
            // Should give only WBTC as burning part with the whole glp amount
            (GmxLens.GlpBurningPart[] memory parts, uint16 partLength) = lens.getTokenOutPartsFromBurningGlp(1_000_000 ether, tokens);
            assertEq(partLength, 1);
            assertEq(parts[0].token, 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f);
            assertEq(parts[0].glpAmount, 1_000_000 ether);
            assertEq(parts[0].tokenAmount, 4039469296); // around 40.394 BTC
            assertEq(parts[0].feeBasisPoints, 11);
        }
    }

    function _addTokens() private {
        uint256 defaultDeltaPercent = 0.5e18;

        tokenInfos.push(
            TokenInfo({
                name: "weth",
                token: IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1),
                expectedMintedGlp: 1071054393648887215298311,
                expectedTokenOut: 599971458461802676177,
                expectedTokenOutPriceUsd: 929073,
                maxGlpBurningDeltaPercent: defaultDeltaPercent
            })
        );
        tokenInfos.push(
            TokenInfo({
                name: "usdc",
                token: IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8),
                expectedMintedGlp: 1069660070885274604266029,
                expectedTokenOut: 930207864238,
                expectedTokenOutPriceUsd: 930114,
                maxGlpBurningDeltaPercent: defaultDeltaPercent
            })
        );
        tokenInfos.push(
            TokenInfo({
                name: "usdt",
                token: IERC20(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9),
                expectedMintedGlp: 1072555972009700796416354,
                expectedTokenOut: 926198749458,
                expectedTokenOutPriceUsd: 926643,
                maxGlpBurningDeltaPercent: defaultDeltaPercent
            })
        );
        tokenInfos.push(
            TokenInfo({
                name: "wbtc",
                token: IERC20(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f),
                expectedMintedGlp: 1068265747718091357642598,
                expectedTokenOut: 4212985044,
                expectedTokenOutPriceUsd: 931359,
                maxGlpBurningDeltaPercent: defaultDeltaPercent
            })
        );
        tokenInfos.push(
            TokenInfo({
                name: "link",
                token: IERC20(0xf97f4df75117a78c1A5a0DBb814Af92458539FB4),
                expectedMintedGlp: 1068373003718862963310328,
                expectedTokenOut: 137250735738259072364749,
                expectedTokenOutPriceUsd: 930518,
                maxGlpBurningDeltaPercent: defaultDeltaPercent
            })
        );
        tokenInfos.push(
            TokenInfo({
                name: "uni",
                token: IERC20(0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0),
                expectedMintedGlp: 1069338304093671694027099,
                expectedTokenOut: 142208708326564643857192,
                expectedTokenOutPriceUsd: 929191,
                maxGlpBurningDeltaPercent: defaultDeltaPercent
            })
        );
        tokenInfos.push(
            TokenInfo({
                name: "dai",
                token: IERC20(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1),
                expectedMintedGlp: 1070518115662882364903163,
                expectedTokenOut: 929089041509702298646702,
                expectedTokenOutPriceUsd: 928826,
                maxGlpBurningDeltaPercent: defaultDeltaPercent
            })
        );
        tokenInfos.push(
            TokenInfo({
                name: "frax",
                token: IERC20(0x17FC002b466eEc40DaE837Fc4bE5c67993ddBd6F),
                expectedMintedGlp: 1069660070885274604266029,
                expectedTokenOut: 929275511964596368350394,
                expectedTokenOutPriceUsd: 929299,
                maxGlpBurningDeltaPercent: defaultDeltaPercent
            })
        );
    }
}
