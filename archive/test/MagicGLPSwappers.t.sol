// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Surl} from "surl/Surl.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import {stdJson} from "forge-std/StdJson.sol";
import "utils/BaseTest.sol";
import "script/MagicGLPSwappers.s.sol";
import "interfaces/IGmxVault.sol";
import "interfaces/IAggregator.sol";
import "interfaces/IOracle.sol";
import "interfaces/IERC4626.sol";

contract MagicGLPSwappersTest is BaseTest {
    using BoringERC20 for IERC20;
    using Surl for *;
    using stdJson for string;

    GmxLens lens;
    MagicGlpSwapper swapper;
    MagicGlpLevSwapper levSwapper;
    IGmxVault gmxVault;
    IBentoBoxV1 box;
    IERC20 magicGlp;
    IERC20 mim;
    address mimWhale;

    mapping(IERC20 => uint256) glpIn;
    mapping(IERC20 => uint256) mimIn;

    function setUp() public override {
        forkArbitrum(Block.Latest);
        super.setUp();

        MagicGLPSwappersScript script = new MagicGLPSwappersScript();
        script.setTesting(true);
        (lens, swapper, levSwapper) = script.deploy();

        mim = IERC20(constants.getAddress("arbitrum.mim"));
        gmxVault = IGmxVault(constants.getAddress("arbitrum.gmx.vault"));
        box = IBentoBoxV1(constants.getAddress("arbitrum.degenBox"));
        magicGlp = IERC20(constants.getAddress("arbitrum.magicGlp"));

        mimWhale = 0x30dF229cefa463e991e29D42DB0bae2e122B2AC7;
    }

    function test() public {
        uint256 mimAmountIn = 50_000 ether;
        uint256 slippageInBips = 100; // 1%

        vm.startPrank(mimWhale);
        mim.approve(address(box), type(uint256).max);

        // empty degenbox mGLP balances if any
        box.transfer(magicGlp, mimWhale, alice, box.balanceOf(magicGlp, mimWhale));
        vm.stopPrank();

        uint256 len = gmxVault.allWhitelistedTokensLength();

        for (uint256 i = 0; i < len; i++) {
            uint256 id = vm.snapshot();

            IERC20 token = IERC20(gmxVault.allWhitelistedTokens(i));

            // skip frax and mim
            if (token == mim || token == IERC20(0x17FC002b466eEc40DaE837Fc4bE5c67993ddBd6F)) continue;

            vm.startPrank(mimWhale);
            box.deposit(mim, mimWhale, address(levSwapper), mimAmountIn, 0);

            console2.log(string.concat("==== ", token.safeName(), " ===="));

            // take the buyAmount from the 0x response but here we are using the price oracle since we can't
            (uint256 buyAmount, bytes memory swapData) = _getSwapDataFrom0x(address(mim), address(token), mimAmountIn);
            uint256 glpAmount = lens.getMintedGlpFromTokenIn(address(token), buyAmount);
            uint256 minAmount = box.toShare(magicGlp, IERC4626(address(magicGlp)).convertToShares(glpAmount), false);
            minAmount -= (minAmount * slippageInBips) / 10_000;

            (, uint256 shareReturned) = levSwapper.swap(
                mimWhale,
                minAmount,
                box.balanceOf(mim, address(levSwapper)),
                abi.encode(swapData, token)
            );

            glpIn[token] = box.toAmount(magicGlp, shareReturned, false);

            console.log("glp minted", glpIn[token]);
            box.transfer(magicGlp, mimWhale, address(swapper), shareReturned);

            uint256 tokenAmount = lens.getTokenOutFromBurningGlp(address(token), IERC4626(address(magicGlp)).convertToAssets(glpIn[token]));
            minAmount = box.toShare(token, tokenAmount, false);

            (buyAmount, swapData) = _getSwapDataFrom0x(address(token), address(mim), tokenAmount);
            (, shareReturned) = swapper.swap(address(0), address(0), mimWhale, minAmount, shareReturned, abi.encode(swapData, token));
            mimIn[token] = box.toAmount(mim, box.balanceOf(mim, mimWhale), false);

            console.log("mim out", mimIn[token], mimIn[token] / 1e18);
            vm.stopPrank();
            vm.revertTo(id);
        }
    }

    function _getSwapDataFrom0x(
        address sellToken,
        address buyToken,
        uint256 sellAmount
    ) private returns (uint256 buyAmount, bytes memory swapData) {
        string memory request = string.concat(
            "https://arbitrum.api.0x.org/swap/v1/quote?buyToken=",
            vm.toString(buyToken),
            "&sellToken=",
            vm.toString(sellToken),
            "&sellAmount=",
            vm.toString(sellAmount)
        );

        console2.log(request);
        string[] memory headers = new string[](1);
        headers[0] = "accept: application/json";

        (uint256 status, bytes memory res) = request.get(headers);
        assertEq(status, 200);
        string memory json = string(res);
        swapData = json.readBytes(".data");
        buyAmount = vm.parseUint(json.readString(".buyAmount"));
    }
}
