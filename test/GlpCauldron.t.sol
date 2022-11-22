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

        degenBox = IBentoBoxV1(cauldron.bentoBox());

        // Whitelist master contract
        vm.startPrank(degenBox.owner());
        degenBox.whitelistMasterContract(address(cauldron.masterContract()), true);
        vm.stopPrank();
    }

    function testArbitrum() public {
        setupArbitrum();

        vm.startPrank(mimWhale);
        degenBox.setMasterContractApproval(mimWhale, address(cauldron.masterContract()), true, 0, "", "");
        mim.approve(address(degenBox), type(uint256).max);
        degenBox.deposit(mim, mimWhale, mimWhale, 1_000_000 ether, 0);
        degenBox.deposit(mim, mimWhale, address(cauldron), 1_000_000 ether, 0);
        vm.stopPrank();

        IGmxRewardRouterV2 router = IGmxRewardRouterV2(constants.getAddress("arbitrum.gmx.rewardRouterV2"));
        IGmxGlpManager manager = IGmxGlpManager(constants.getAddress("arbitrum.gmx.glpManager"));

        uint256 amount = _mintGlpAndWaitCooldown(router, manager, 50 ether, address(cauldron));

        vm.startPrank(alice);
        uint256 share = degenBox.toShare(IERC20(address(sGlp)), amount, false);
        cauldron.addCollateral(alice, true, share);

        uint256 priceFeed = oracle.peekSpot("");
        uint256 collateralValue = (amount * 1e18) / priceFeed;

        console2.log("oracle feed", priceFeed);
        console2.log("collateral amount", amount);
        console2.log("collateral value", collateralValue);

        uint256 ltv = cauldron.COLLATERIZATION_RATE();
        console2.log("ltv", ltv);

        // borrow max minus 1%
        uint256 expectedMimAmount = (collateralValue * (ltv - 1e3)) / 1e5;
        console2.log("expected borrow amount", expectedMimAmount);
        assertEq(degenBox.toAmount(mim, degenBox.balanceOf(mim, alice), false), 0);
        cauldron.borrow(alice, expectedMimAmount);
        assertGe(degenBox.toAmount(mim, degenBox.balanceOf(mim, alice), false), expectedMimAmount);
        console2.log("borrowed amount", degenBox.toAmount(mim, degenBox.balanceOf(mim, alice), false));

        vm.stopPrank();

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

            console2.log("liquidator sGlp balance", degenBox.balanceOf(sGlp, mimWhale));
            actions[0] = 31;
            values[0] = 0;
            datas[0] = abi.encode(borrowers, maxBorrows, mimWhale, address(0), "");
            cauldron.cook(actions, values, datas);
            vm.stopPrank();

            console2.log("alice borrow part after liquidation", cauldron.userBorrowPart(alice));
            console2.log("liquidator sGlp balance after liquidation", degenBox.balanceOf(sGlp, mimWhale));
        }
    }

    function _mintGlpAndWaitCooldown(
        IGmxRewardRouterV2 router,
        IGmxGlpManager manager,
        uint256 value,
        address recipient
    ) private returns (uint256) {
        vm.startPrank(deployer);
        uint256 amount = router.mintAndStakeGlpETH{value: value}(0, 0);
        advanceTime(manager.cooldownDuration());
        sGlp.approve(address(degenBox), amount);
        degenBox.deposit(sGlp, address(deployer), recipient, amount, 0);
        vm.stopPrank();

        return amount;
    }
}
