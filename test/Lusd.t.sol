// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "interfaces/IBentoBoxV1.sol";

contract LusdTest is BaseTest {
    function setUp() public override {
        forkMainnet(16534558);
        super.setUp();
    }

    function test() public {
        address cauldron = 0x8227965A7f42956549aFaEc319F4E444aa438Df5;
        address safe = constants.getAddress("mainnet.safe.ops");
        IBentoBoxV1 degenBox = IBentoBoxV1(constants.getAddress("mainnet.degenBox"));
        IERC20 lusd = IERC20(constants.getAddress("mainnet.liquity.lusd"));

        {
            (uint64 strategyStartDate, uint64 targetPercentage, uint128 balance) = IBentoBoxV1(degenBox).strategyData(lusd);
            assertEq(strategyStartDate, 0);
            assertEq(targetPercentage, 90);
            assertEq(balance, 249873601334860402517583); // 249,873 LUSD in strat ✔

            uint256 lusdCauldron = degenBox.toAmount(lusd, degenBox.balanceOf(lusd, cauldron), false);
            assertEq(lusdCauldron, 277609634715901037124987); // 277,609 LUSD in cauldron, 90% in strat ✔

            uint256 lusdDegenBox = lusd.balanceOf(address(degenBox));
            assertEq(lusdDegenBox, 27763733481651155835287); // 27,763 LUSD in degenbox ✔
        }

        pushPrank(safe);
        degenBox.setStrategyTargetPercentage(lusd, 0);
        degenBox.harvest(lusd, true, 999999999999999999999999999999999999999999999999);
        popPrank();

        {
            (uint64 strategyStartDate, uint64 targetPercentage, uint128 balance) = IBentoBoxV1(degenBox).strategyData(lusd);
            assertEq(strategyStartDate, 0);
            assertEq(targetPercentage, 0);
            assertEq(balance, 6919136364490776190395); // 6,919 LUSD in the strat ?

            uint256 lusdCauldron = degenBox.toAmount(lusd, degenBox.balanceOf(lusd, cauldron), false);
            assertEq(lusdCauldron, 277609634715901037124987); // 277,609 LUSD in cauldron, 0% in strat ✔

            uint256 lusdDegenBox = lusd.balanceOf(address(degenBox));
            assertEq(lusdDegenBox, 270718198452020782162475); // 270,718 LUSD in degenbox, loss = 6,891 LUSD, still in the strat?
        }
    }
}
