// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "BoringSolidity/ERC20.sol";
import "utils/BaseTest.sol";
import "script/Liquity.s.sol";
import "interfaces/ICauldronV3.sol";

contract LiquityTest is BaseTest {
    event StabilityPoolETHBalanceUpdated(uint256 _newBalance);
    event RewardSwapped(IERC20 token, uint256 total, uint256 amountOut, uint256 feeAmount);
    event LogStrategyProfit(address indexed token, uint256 amount);
    event LogStrategyDivest(address indexed token, uint256 amount);
    event LogStrategyQueued(address indexed token, address indexed strategy);
    event LogStrategyLoss(address indexed token, uint256 amount);

    address constant lusdWhale = 0x3DdfA8eC3052539b6C9549F12cEA2C295cfF5296;
    ProxyOracle public oracle;
    ISwapperV2 public swapper;
    ICauldronV3 public cauldron;
    IBentoBoxV1 degenBox;
    ILevSwapperV2 public levSwapper;
    LiquityStabilityPoolStrategy public strategy;
    ERC20 lqtyToken;
    ERC20 lusdToken;

    function setUp() public override {
        forkMainnet(15436912);
        super.setUp();

        LiquityScript script = new LiquityScript();
        script.setTesting(true);
        (cauldron, oracle, swapper, levSwapper, strategy) = script.run();

        degenBox = IBentoBoxV1(constants.getAddress("mainnet.degenBox"));
        lqtyToken = ERC20(constants.getAddress("mainnet.liquity.lqty"));
        lusdToken = ERC20(constants.getAddress("mainnet.liquity.lusd"));

        _depositLusdToDegenBox();
        _activateStrategy();
    }

    function testOracle() public {
        assertEq(oracle.peekSpot(""), 986675860117660898); // around $1.01
    }

    function testFarmRewards() public {
        uint256 previousAmountLQTY = lqtyToken.balanceOf(address(strategy));
        uint256 previousAmountETH = address(strategy).balance;

        _distributeRewards();

        vm.startPrank(deployer);
        strategy.safeHarvest(type(uint256).max, false, 0, false);
        vm.stopPrank();

        assertGt(lqtyToken.balanceOf(address(strategy)), previousAmountLQTY, "no LQTY reward harvested");
        assertGt(address(strategy).balance, previousAmountETH, "no ETH reward harvested");
    }

    function testFeeParameters() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        strategy.setFeeParameters(alice, 15);

        vm.prank(deployer);
        strategy.setFeeParameters(alice, 15);
        assertEq(strategy.feeCollector(), alice);
        assertEq(strategy.feePercent(), 15);
    }

    function testSwapRewardTokenDisabled() public {
        _distributeRewards();

        vm.startPrank(deployer);
        strategy.setRewardTokenEnabled(IERC20(address(0)), false);
        strategy.setRewardTokenEnabled(IERC20(constants.getAddress("mainnet.liquity.lqty")), false);
        strategy.safeHarvest(type(uint256).max, false, 0, false);

        vm.expectRevert(abi.encodeWithSignature("InsupportedToken(address)", address(0)));
        strategy.swapRewards(0, IERC20(address(0)), "");
        vm.expectRevert(abi.encodeWithSignature("InsupportedToken(address)", address(lqtyToken)));
        strategy.swapRewards(0, lqtyToken, "");

        vm.stopPrank();
    }

    function testSwapETHRewardsTakeFees() public {
        uint256 degenBoxBalance = degenBox.totals(lusdToken).elastic;
        vm.prank(deployer);
        strategy.setFeeParameters(deployer, 10);

        _distributeRewards();

        vm.startPrank(deployer);
        strategy.safeHarvest(0, false, 0, false);

        // make sure the frontend tag doesn't receive anything
        assertEq(address(strategy.tag()).balance, 0);
        assertEq(lqtyToken.balanceOf(strategy.tag()), 0);

        uint256 balanceFeeCollector = lusdToken.balanceOf(deployer);
        uint256 balanceStrategy = lusdToken.balanceOf(address(strategy));

        vm.expectEmit(true, false, false, false);
        emit RewardSwapped(IERC20(address(0)), 0, 0, 0);

        // https://api.0x.org/swap/v1/quote?buyToken=0x5f98805A4E8be255a32880FDeC7F6728C6568bA0&sellToken=ETH&sellAmount=6869198913752000000
        strategy.swapRewards(
            0,
            IERC20(address(0)),
            hex"3598d8ab000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000022e307e628383f3153800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000042c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20001f46b175474e89094c44da98b954eedeac495271d0f0001f45f98805a4e8be255a32880fdec7f6728c6568ba0000000000000000000000000000000000000000000000000000000000000869584cd000000000000000000000000100000000000000000000000000000000000001100000000000000000000000000000000000000000000007b62b83992630d47ec"
        );

        // Strategy and FeeCollector should now have more strategy token
        assertGt(lusdToken.balanceOf(deployer), balanceFeeCollector);
        assertGt(lusdToken.balanceOf(address(strategy)), balanceStrategy);

        vm.expectEmit(true, false, false, false);
        emit LogStrategyProfit(address(lusdToken), 0);
        strategy.safeHarvest(0, false, 0, false);

        assertGt(degenBox.totals(lusdToken).elastic, degenBoxBalance);
    }

    function testSwapLQTYRewardsTakeFees() public {
        uint256 degenBoxBalance = degenBox.totals(lusdToken).elastic;
        vm.prank(deployer);
        strategy.setFeeParameters(deployer, 10);

        _distributeRewards();

        vm.startPrank(deployer);
        strategy.safeHarvest(0, false, 0, false);

        // make sure the frontend tag doesn't receive anything
        assertEq(address(strategy.tag()).balance, 0);
        assertEq(lqtyToken.balanceOf(strategy.tag()), 0);

        uint256 balanceFeeCollector = lusdToken.balanceOf(deployer);
        uint256 balanceStrategy = lusdToken.balanceOf(address(strategy));

        vm.expectEmit(true, false, false, false);
        emit RewardSwapped(IERC20(address(0)), 0, 0, 0);

        // https://api.0x.org/swap/v1/quote?buyToken=0x5f98805A4E8be255a32880FDeC7F6728C6568bA0&sellToken=0x6DEA81C8171D0bA574754EF6F8b412F2Ed88c54D&sellAmount=21262309821713261000000
        strategy.swapRewards(
            0,
            lqtyToken,
            hex"415565b00000000000000000000000006dea81c8171d0ba574754ef6f8b412f2ed88c54d0000000000000000000000005f98805a4e8be255a32880fdec7f6728c6568ba0000000000000000000000000000000000000000000000480a1d2f24d7e17f540000000000000000000000000000000000000000000000414034dc46e1edd0da400000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000003e00000000000000000000000000000000000000000000000000000000000000940000000000000000000000000000000000000000000000000000000000000001900000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000320000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006dea81c8171d0ba574754ef6f8b412f2ed88c54d000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000002e000000000000000000000000000000000000000000000000000000000000002e000000000000000000000000000000000000000000000000000000000000002c0000000000000000000000000000000000000000000000480a1d2f24d7e17f54000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000012556e6973776170563300000000000000000000000000000000000000000000000000000000000480a1d2f24d7e17f5400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000e592427a0aece92de3edee1f18e0157c05861564000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000426dea81c8171d0ba574754ef6f8b412f2ed88c54d000bb8c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20001f4a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000190000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000005f98805a4e8be255a32880fdec7f6728c6568ba0000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000004c000000000000000000000000000000000000000000000000000000000000004c000000000000000000000000000000000000000000000000000000000000004a0ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000001942616c616e6365725632000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000414034dc46e1edd0da4000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000002a0000000000000000000000000ba12222222228d8ba445958a75a0704d566bf2c8000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000002200000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000e006df3b2bbb68adc8b0e302443692037ed9f91b4200000000000000000000006300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001408485b36623632ffa5e486008df4d0b6d363defdb00020000000000000000034a00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000006b175474e89094c44da98b954eedeac495271d0f0000000000000000000000005f98805a4e8be255a32880fdec7f6728c6568ba0000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000030000000000000000000000006dea81c8171d0ba574754ef6f8b412f2ed88c54d000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee0000000000000000000000000000000000000000000000000000000000000000869584cd00000000000000000000000010000000000000000000000000000000000000110000000000000000000000000000000000000000000000143fd13f47630d4f88"
        );

        // Strategy and FeeCollector should now have more strategy token
        assertGt(lusdToken.balanceOf(deployer), balanceFeeCollector);
        assertGt(lusdToken.balanceOf(address(strategy)), balanceStrategy);

        vm.expectEmit(true, false, false, false);
        emit LogStrategyProfit(address(lusdToken), 0);
        strategy.safeHarvest(0, false, 0, false);

        assertGt(degenBox.totals(lusdToken).elastic, degenBoxBalance);
    }

    function testStrategyDivest() public {
        uint256 degenBoxBalance = lusdToken.balanceOf(address(degenBox));

        vm.prank(degenBox.owner());
        degenBox.setStrategyTargetPercentage(lusdToken, 50);

        vm.expectEmit(true, false, false, false);
        emit LogStrategyDivest(address(lusdToken), 0);
        vm.prank(deployer);
        strategy.safeHarvest(0, true, 0, false);

        assertGt(lusdToken.balanceOf(address(degenBox)), degenBoxBalance);
    }

    function testStrategyExit() public {
        uint256 degenBoxBalance = lusdToken.balanceOf(address(degenBox));

        _distributeRewards();

        vm.prank(deployer);
        strategy.safeHarvest(0, true, 0, false);

        vm.prank(deployer);
        strategy.swapRewards(
            0,
            IERC20(address(0)),
            hex"3598d8ab000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000022e307e628383f3153800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000042c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20001f46b175474e89094c44da98b954eedeac495271d0f0001f45f98805a4e8be255a32880fdec7f6728c6568ba0000000000000000000000000000000000000000000000000000000000000869584cd000000000000000000000000100000000000000000000000000000000000001100000000000000000000000000000000000000000000007b62b83992630d47ec"
        );

        vm.expectEmit(true, true, false, false);
        emit LogStrategyQueued(address(lusdToken), address(strategy));

        vm.startPrank(degenBox.owner());
        degenBox.setStrategy(lusdToken, strategy);
        advanceTime(1210000);

        vm.expectEmit(true, false, false, false);
        emit LogStrategyProfit(address(lusdToken), 0);
        vm.expectEmit(true, false, false, false);
        emit LogStrategyDivest(address(lusdToken), 0);
        degenBox.setStrategy(lusdToken, strategy);
        vm.stopPrank();

        assertGt(lusdToken.balanceOf(address(degenBox)), degenBoxBalance);
        assertEq(lusdToken.balanceOf(address(strategy)), 0);
    }

    function testStrategyExitWithLoss() public {
        uint256 degenBoxBalance = 10_000_000 ether;
        //console2.log("degenBoxBalance before", degenBoxBalance);
        //console2.log("lusd deposit before loss", strategy.pool().getCompoundedLUSDDeposit(address(strategy)));

        _simulateLUSDLoss();
        //console2.log("lusd deposit after loss", strategy.pool().getCompoundedLUSDDeposit(address(strategy)));
        vm.startPrank(degenBox.owner());
        degenBox.setStrategy(lusdToken, strategy);
        advanceTime(1210000);

        vm.expectEmit(true, false, false, false);
        emit LogStrategyLoss(address(lusdToken), 0);
        vm.expectEmit(true, false, false, false);
        emit LogStrategyDivest(address(lusdToken), 0);
        degenBox.setStrategyTargetPercentage(lusdToken, 0);
        degenBox.setStrategy(lusdToken, strategy);

        vm.stopPrank();
        //console2.log("degenBoxBalance after exiting strat", lusdToken.balanceOf(address(degenBox)));

        assertLt(lusdToken.balanceOf(address(degenBox)), degenBoxBalance);
        assertEq(lusdToken.balanceOf(address(strategy)), 0);
    }

    function _depositLusdToDegenBox() private {
        vm.startPrank(lusdWhale);
        lusdToken.approve(address(degenBox), type(uint256).max);
        degenBox.deposit(lusdToken, lusdWhale, alice, 10_000_000 * 1e18, 0);
        vm.stopPrank();
    }

    function _simulateLUSDLoss() private {
        // dummy offset from trove manager to trigger ETH rewards distribution
        vm.startPrank(0xA39739EF8b0231DbFA0DcdA07d7e29faAbCf4bb2);
        strategy.pool().offset(30e24, 0);
        vm.stopPrank();
    }

    function _distributeRewards() private {
        advanceTime(1210000);

        vm.startPrank(bob);
        vm.expectEmit(true, false, false, false);
        emit StabilityPoolETHBalanceUpdated(10e18);
        (bool failed, ) = address(strategy).call{value: 10e18}("");
        assertEq(failed, false);
        vm.stopPrank();

        // dummy offset from trove manager to trigger ETH rewards distribution
        vm.startPrank(0xA39739EF8b0231DbFA0DcdA07d7e29faAbCf4bb2);
        strategy.pool().offset(1e8, 100e18);
        vm.stopPrank();
    }

    function _activateStrategy() private {
        vm.startPrank(degenBox.owner());
        degenBox.setStrategy(lusdToken, strategy);
        advanceTime(1210000);
        degenBox.setStrategy(lusdToken, strategy);
        degenBox.setStrategyTargetPercentage(lusdToken, 70);
        vm.stopPrank();

        // Initial Rebalance, calling skim to deposit to the gauge
        vm.startPrank(deployer);
        strategy.safeHarvest(type(uint256).max, true, 0, false);
        assertEq(lusdToken.balanceOf(address(strategy)), 0);
        assertEq(lqtyToken.balanceOf(address(strategy)), 0);
        assertEq(address(strategy).balance, 0);
        vm.stopPrank();
    }
}
