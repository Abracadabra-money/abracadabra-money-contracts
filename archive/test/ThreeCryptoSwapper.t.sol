// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/ThreeCrypto.s.sol";

contract ThreeCryptoSwapperTest is BaseTest {
    ProxyOracle public oracle;
    ThreeCryptoLevSwapper levSwapper;
    ThreeCryptoSwapper swapper;
    ICauldronV4 cauldron;

    function setUp() public override {
        forkMainnet(16513645);
        super.setUp();

        ThreeCryptoScript script = new ThreeCryptoScript();
        script.setTesting(true);
        (oracle, levSwapper, swapper, cauldron) = script.deploy();
    }

    function test() public {
        console2.log("oracle price: ", oracle.peekSpot(""));

        address mimWhale = 0xDF2C270f610Dc35d8fFDA5B453E74db5471E126B;
        vm.startPrank(mimWhale);
        cauldron.magicInternetMoney().approve(cauldron.bentoBox(), type(uint256).max);
        IBentoBoxV1(cauldron.bentoBox()).deposit(cauldron.magicInternetMoney(), mimWhale, address(levSwapper), 0, 100000 * 1e18);
        vm.stopPrank();
        console2.log("lev swapper balance", IBentoBoxV1(cauldron.bentoBox()).balanceOf(cauldron.magicInternetMoney(), address(levSwapper)));
        (, uint256 shareReturned) = levSwapper.swap(address(swapper), 0, 100000 * 1e18);
        console2.log("swapper balance", IBentoBoxV1(cauldron.bentoBox()).balanceOf(cauldron.collateral(), address(swapper)), shareReturned);
        swapper.swap(IERC20(address(0)), IERC20(address(0)), address(cauldron), 0, shareReturned);
        console2.log("cauldron balance", cauldron.magicInternetMoney().balanceOf(address(cauldron)));
    }
}
