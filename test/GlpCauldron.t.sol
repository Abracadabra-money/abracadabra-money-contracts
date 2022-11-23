// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/GlpCauldron.s.sol";
import "interfaces/IGmxGlpManager.sol";
import "interfaces/IGmxRewardRouterV2.sol";
import "interfaces/IGmxStakedGlp.sol";
import "interfaces/IOracle.sol";

contract GlpCauldronTest is BaseTest {
    CauldronV4 masterContract;
    DegenBoxOwner degenBoxOwner;
    ICauldronV4 cauldron;
    ProxyOracle oracle;
    IBentoBoxV1 degenBox;
    address mimWhale;
    ERC20 mim;
    IERC20 sGlp;
    GmxGlpWrapper wsGlp;
    IGmxRewardRouterV2 router;
    IGmxGlpManager manager;

    function setUp() public override {}

    function setupArbitrum() public {
        forkArbitrum(39407131);
        super.setUp();

        mim = ERC20(constants.getAddress("arbitrum.mim"));
        mimWhale = 0x30dF229cefa463e991e29D42DB0bae2e122B2AC7;
        GlpCauldronScript script = new GlpCauldronScript();
        script.setTesting(true);
        sGlp = IERC20(constants.getAddress("arbitrum.gmx.sGLP"));
        (masterContract, degenBoxOwner, cauldron, oracle, wsGlp) = script.run();

        router = IGmxRewardRouterV2(constants.getAddress("arbitrum.gmx.rewardRouterV2"));
        manager = IGmxGlpManager(constants.getAddress("arbitrum.gmx.glpManager"));
        _setup();
    }

    function _setup() private {
        degenBox = IBentoBoxV1(cauldron.bentoBox());

        // Whitelist master contract
        vm.startPrank(degenBox.owner());
        degenBox.whitelistMasterContract(address(cauldron.masterContract()), true);
        vm.stopPrank();
    }

    function setupBorrow(address borrower, uint256 collateralAmount) public {
        vm.startPrank(mimWhale);
        degenBox.setMasterContractApproval(mimWhale, address(cauldron.masterContract()), true, 0, "", "");
        mim.approve(address(degenBox), type(uint256).max);
        degenBox.deposit(mim, mimWhale, mimWhale, 1_000_000 ether, 0);
        degenBox.deposit(mim, mimWhale, address(cauldron), 1_000_000 ether, 0);
        vm.stopPrank();

        uint256 amount = _mintGlpWrapAndWaitCooldown(collateralAmount, address(cauldron));

        uint256 expectedMimAmount;
        {
            vm.startPrank(borrower);
            cauldron.addCollateral(borrower, true, degenBox.toShare(IERC20(address(sGlp)), amount, false));

            uint256 collateralValue = (amount * 1e18) / oracle.peekSpot("");

            console2.log("collateral amount", amount);
            console2.log("collateral value", collateralValue);

            uint256 ltv = cauldron.COLLATERIZATION_RATE();
            console2.log("ltv", ltv);

            // borrow max minus 1%
            expectedMimAmount = (collateralValue * (ltv - 1e3)) / 1e5;
        }

        console2.log("expected borrow amount", expectedMimAmount);
        assertEq(degenBox.toAmount(mim, degenBox.balanceOf(mim, borrower), false), 0);
        cauldron.borrow(borrower, expectedMimAmount);
        assertGe(degenBox.toAmount(mim, degenBox.balanceOf(mim, borrower), false), expectedMimAmount);
        console2.log("borrowed amount", degenBox.toAmount(mim, degenBox.balanceOf(mim, borrower), false));

        vm.stopPrank();
    }

    function testArbitrumLiquidation() public {
        setupArbitrum();
        setupBorrow(alice, 50 ether);
        _testLiquidation();
    }

    function testArbitrumRewardHarvesting() public {
        setupArbitrum();

        // check fallback permission
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSignature("ErrNotStrategyExecutor(address)", bob));
        GmxGlpRewardHandler(address(wsGlp)).swapRewards(0, IERC20(address(0)), IERC20(address(0)), address(0), "");

        // permissionless
        GmxGlpRewardHandler(address(wsGlp)).harvest();

        vm.stopPrank();
    }

    function _testLiquidation() private {
        uint256 priceFeed = oracle.peekSpot("");

        // drop glp price in half to open liquidation.
        vm.mockCall(address(oracle), abi.encodeWithSelector(ProxyOracle.get.selector, ""), abi.encode(true, priceFeed * 2));
        {
            vm.startPrank(mimWhale);
            uint8[] memory actions = new uint8[](1);
            uint256[] memory values = new uint256[](1);
            bytes[] memory datas = new bytes[](1);

            address[] memory borrowers = new address[](1);
            uint256[] memory maxBorrows = new uint256[](1);

            borrowers[0] = alice;

            console2.log("alice borrow part", cauldron.userBorrowPart(alice));
            maxBorrows[0] = cauldron.userBorrowPart(alice) / 2;

            assertEq(degenBox.balanceOf(wsGlp, mimWhale), 0);
            actions[0] = 31;
            values[0] = 0;
            datas[0] = abi.encode(borrowers, maxBorrows, mimWhale, address(0), "");
            cauldron.cook(actions, values, datas);
            vm.stopPrank();

            console2.log("alice borrow part after liquidation", cauldron.userBorrowPart(alice));
            assertGt(degenBox.balanceOf(wsGlp, mimWhale), 0);

            console2.log("liquidator sGlp balance after liquidation", degenBox.balanceOf(wsGlp, mimWhale));
        }
    }

    function _mintGlpWrapAndWaitCooldown(uint256 value, address recipient) private returns (uint256) {
        vm.startPrank(deployer);
        uint256 amount = router.mintAndStakeGlpETH{value: value}(0, 0);
        advanceTime(manager.cooldownDuration());
        sGlp.approve(address(wsGlp), amount);
        wsGlp.enterFor(amount, address(degenBox));
        degenBox.deposit(wsGlp, address(degenBox), recipient, amount, 0);
        vm.stopPrank();

        return amount;
    }
}
