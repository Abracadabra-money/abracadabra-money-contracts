// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/VelodromeVolatileOpUsdc.s.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/ICauldronV3.sol";
import "interfaces/ISwapperV2.sol";
import "interfaces/ILevSwapperV2.sol";

interface IVelodromePairFactory {
    function volatileFee() external view returns (uint256);
}

contract VelodromeVolatileOpUsdcTest is BaseTest {
    address constant opWhale = 0x2501c477D0A35545a387Aa4A3EEe4292A9a8B3F0;
    address constant usdcWhale = 0xAD7b4C162707E0B2b5f6fdDbD3f8538A5fbA0d60;
    address constant rewardDistributor = 0x5d5Bea9f0Fc13d967511668a60a3369fD53F784F;

    ICauldronV3 cauldron;
    IBentoBoxV1 degenBox;
    ISwapperV2 swapper;
    ILevSwapperV2 levswapper;
    SolidlyGaugeVolatileLPStrategy strategy;
    ERC20 veloToken;
    ISolidlyGauge gauge;
    IVelodromePairFactory pairFactory;
    ISolidlyRouter router;

    uint256 fee;

    function setUp() public override {
        super.setUp();

        vm.createSelectFork(vm.envString("OPTIMISM_RPC_URL"), 16849588);
        VelodromeVolatileOpUsdcScript script = new VelodromeVolatileOpUsdcScript();
        script.setTesting(true);
        (cauldron, degenBox, swapper, levswapper, strategy) = script.run();

        gauge = ISolidlyGauge(constants.getAddress("optimism.velodrome.vOpUsdcGauge"));
        pairFactory = IVelodromePairFactory(constants.getAddress("optimism.velodrome.factory"));
        router = ISolidlyRouter(constants.getAddress("optimism.velodrome.router"));
        fee = pairFactory.volatileFee();
    }

    function distributeReward() private {
        advanceTime(1210000);
        uint256 amount = 50_000 * 1e18;

        vm.startPrank(rewardDistributor);
        veloToken.transfer(address(gauge), amount);
        vm.stopPrank();

        vm.startPrank(address(gauge));
        veloToken.approve(address(gauge), 0);
        veloToken.approve(address(gauge), amount);
        gauge.notifyRewardAmount(address(veloToken), amount);
        vm.stopPrank();
    }

    function testExample() public {
        /*vm.startPrank(c.owner());
        c.setOwner(0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045);
        vm.stopPrank();
        assertEq(alice.balance, 100 ether);
        assertTrue(c.owner() != constants.getAddress("xMerlin"));
        assertTrue(d.owner() != constants.getAddress("xMerlin"));
        assertEq(c.mim(), 0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3);*/
    }
}
