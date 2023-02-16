// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "BoringSolidity/libraries/BoringERC20.sol";
import "utils/BaseTest.sol";
import "script/GmxLens.s.sol";
import "lenses/GmxLens.sol";

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
    }

    TokenInfo[] tokenInfos;

    function setUp() public override {
        forkArbitrum(61030822);
        super.setUp();

        GmxLensScript script = new GmxLensScript();
        script.setTesting(true);
        (lens) = script.run();

        feed = IVaultPriceFeed(0x2d68011bcA022ed0E474264145F46CC4de96a002);
    }

    function test() public {
        uint256 amountInUsd = 1_000_000 ether;
        IGmxVault vault = lens.vault();

        tokenInfos.push(
            TokenInfo({
                name: "weth",
                token: IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1),
                expectedMintedGlp: 1071054393648887215298311,
                expectedTokenOut: 599971458461802676177,
                expectedTokenOutPriceUsd: 929073
            })
        );
        tokenInfos.push(
            TokenInfo({
                name: "usdc",
                token: IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8),
                expectedMintedGlp: 1069660070885274604266029,
                expectedTokenOut: 930207864238,
                expectedTokenOutPriceUsd: 930114
            })
        );
        tokenInfos.push(
            TokenInfo({
                name: "usdt",
                token: IERC20(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9),
                expectedMintedGlp: 1072555972009700796416354,
                expectedTokenOut: 926198749458,
                expectedTokenOutPriceUsd: 926643
            })
        );
        tokenInfos.push(
            TokenInfo({
                name: "wbtc",
                token: IERC20(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f),
                expectedMintedGlp: 1068265747718091357642598,
                expectedTokenOut: 4212985044,
                expectedTokenOutPriceUsd: 931359
            })
        );
        tokenInfos.push(
            TokenInfo({
                name: "link",
                token: IERC20(0xf97f4df75117a78c1A5a0DBb814Af92458539FB4),
                expectedMintedGlp: 1068373003718862963310328,
                expectedTokenOut: 137250735738259072364749,
                expectedTokenOutPriceUsd: 930518
            })
        );
        tokenInfos.push(
            TokenInfo({
                name: "uni",
                token: IERC20(0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0),
                expectedMintedGlp: 1069338304093671694027099,
                expectedTokenOut: 142208708326564643857192,
                expectedTokenOutPriceUsd: 929191
            })
        );
        tokenInfos.push(
            TokenInfo({
                name: "dai",
                token: IERC20(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1),
                expectedMintedGlp: 1070518115662882364903163,
                expectedTokenOut: 929089041509702298646702,
                expectedTokenOutPriceUsd: 928826
            })
        );
        tokenInfos.push(
            TokenInfo({
                name: "frax",
                token: IERC20(0x17FC002b466eEc40DaE837Fc4bE5c67993ddBd6F),
                expectedMintedGlp: 1069660070885274604266029,
                expectedTokenOut: 929275511964596368350394,
                expectedTokenOutPriceUsd: 929299
            })
        );

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
}
