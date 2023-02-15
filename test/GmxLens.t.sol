// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "BoringSolidity/libraries/BoringERC20.sol";
import "utils/BaseTest.sol";
import "lenses/GmxLens.sol";

contract GmxLensTest is BaseTest {
    using BoringERC20 for IERC20;
    GmxLens lens;
    IVaultPriceFeed feed;

    struct TokenInfo {
        string name;
        IERC20 token;
    }

    TokenInfo[] tokenInfos;

    function setUp() public override {
        forkArbitrum(61021251);
        super.setUp();

        lens = new GmxLens(
            IGmxGlpManager(constants.getAddress("arbitrum.gmx.glpManager")),
            IGmxVault(constants.getAddress("arbitrum.gmx.vault"))
        );

        feed = IVaultPriceFeed(0x2d68011bcA022ed0E474264145F46CC4de96a002);
    }

    function test() public {
        uint256 amountInUsd = 1_000_000 ether;
        IGmxVault vault = lens.vault();

        tokenInfos.push(TokenInfo({name: "weth", token: IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1)}));
        tokenInfos.push(TokenInfo({name: "usdc", token: IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8)}));
        tokenInfos.push(TokenInfo({name: "usdt", token: IERC20(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9)}));
        tokenInfos.push(TokenInfo({name: "wbtc", token: IERC20(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f)}));
        tokenInfos.push(TokenInfo({name: "link", token: IERC20(0xf97f4df75117a78c1A5a0DBb814Af92458539FB4)}));
        tokenInfos.push(TokenInfo({name: "uni", token: IERC20(0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0)}));
        tokenInfos.push(TokenInfo({name: "dai", token: IERC20(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1)}));
        tokenInfos.push(TokenInfo({name: "frax", token: IERC20(0x17FC002b466eEc40DaE837Fc4bE5c67993ddBd6F)}));

        for (uint256 i = 0; i < tokenInfos.length; i++) {
            TokenInfo storage info = tokenInfos[i];

            console2.log("===");
            console2.log(info.name);

            uint8 decimals = info.token.safeDecimals();
            uint256 price = vault.getMinPrice(address(info.token)) / 1e12; // 18 decimals
            uint tokenAmount = (amountInUsd * 10**decimals) / price;

            console2.log("token amount", tokenAmount);
            uint glpAmount = lens.getMintedGlpFromTokenIn(address(info.token), tokenAmount);
            console2.log("glp amount", glpAmount);
        }
    }
}
