// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/GlpCauldron.s.sol";
import "interfaces/IGmxGlpManager.sol";
import "interfaces/IGmxRewardRouterV2.sol";
import "interfaces/IGmxStakedGlp.sol";

contract GlpCauldronTest is BaseTest {
    CauldronV4 masterContract;
    DegenBoxOwner degenBoxOwner;
    ICauldronV4 cauldron;
    IBentoBoxV1 box;
    address mimWhale;
    ERC20 mim;

    function setUp() public override {}

    function setupArbitrum() public {
        forkArbitrum(39407131);
        super.setUp();

        mim = ERC20(constants.getAddress("arbitrum.mim"));
        mimWhale = 0x30dF229cefa463e991e29D42DB0bae2e122B2AC7;
        GlpCauldronScript script = new GlpCauldronScript();
        script.setTesting(true);
        (masterContract, degenBoxOwner, cauldron) = script.run();
    }

    function testArbitrum() public {
        setupArbitrum();

        vm.startPrank(mimWhale);
        box = IBentoBoxV1(cauldron.bentoBox());
        mim.approve(address(box), type(uint256).max);
        box.deposit(mim, mimWhale, address(cauldron), 1_000_000 ether, 0);
        vm.stopPrank();

        IGmxRewardRouterV2 router = IGmxRewardRouterV2(constants.getAddress("arbitrum.gmx.rewardRouterV2"));
        IGmxGlpManager manager = IGmxGlpManager(constants.getAddress("arbitrum.gmx.glpManager"));
        IGmxStakedGlp sGlp = IGmxStakedGlp(constants.getAddress("arbitrum.gmx.sGLP"));

        uint256 amount = mintGlpAndWaitCooldown(router, manager, sGlp, 50, address(cauldron));

        vm.startPrank(alice);
        uint256 share = box.toShare(IERC20(address(sGlp)), amount, false);
        cauldron.addCollateral(alice, true, share);
        vm.stopPrank();
    }

    function mintGlpAndWaitCooldown(
        IGmxRewardRouterV2 router,
        IGmxGlpManager manager,
        IGmxStakedGlp sGlp,
        uint256 value,
        address recipient
    ) public returns (uint256) {
        vm.startPrank(deployer);
        uint256 amount = router.mintAndStakeGlpETH{value: value}(0, 0);
        advanceTime(manager.cooldownDuration());
        sGlp.approve(address(box), amount);
        box.deposit(IERC20(address(sGlp)), address(deployer), recipient, amount, 0);
        vm.stopPrank();

        return amount;
    }
}
