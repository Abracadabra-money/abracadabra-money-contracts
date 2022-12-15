// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/MimCauldronDistributorV4.s.sol";
import "script/CauldronV4WithRewarder.s.sol";
import "script/Rewarder.s.sol";
import "periphery/GlpWrapperHarvestor.sol";
import "utils/CauldronLib.sol";

contract MimCauldronDistributorTest is BaseTest {
    MimCauldronDistributor distributor;
    GlpWrapperHarvestor harvestor;
    CauldronV4WithRewarder cauldron;
    Rewarder rewarder;
    ERC20 mim;
    address distributorOwner;
    address constant whale = 0xADeED59F446cb0a141837e8f7c22710d759Cba65;
    IBentoBoxV1 degenBox;

    function setUp() public override {
        forkArbitrum(43095973);
        super.setUp();

        {
            MimCauldronDistributorScript script = new MimCauldronDistributorScript();
            script.setTesting(true);
            (distributor) = script.run();
        }

        address testContract = address(this);

        mim = ERC20(constants.getAddress("arbitrum.mim"));
        harvestor = GlpWrapperHarvestor(0xf9cE23237B25E81963b500781FA15d6D38A0DE62);
        vm.startPrank(harvestor.owner());
        harvestor.setDistributor(IMimCauldronDistributor(address(distributor)));

        distributorOwner = distributor.owner();
        vm.stopPrank();
        vm.startPrank(distributorOwner);
        distributor.setOperator(testContract, true);
        vm.stopPrank();

        {
            CauldronV4WithRewarderScript script = new CauldronV4WithRewarderScript();
            script.setTesting(true);
            (cauldron) = script.run();
        }

        degenBox = cauldron.bentoBox();

        vm.startPrank(degenBox.owner());
        degenBox.whitelistMasterContract(address(cauldron.masterContract()), true);
        vm.stopPrank();

        {
            RewarderScript script = new RewarderScript();
            script.setTesting(true);
            (rewarder) = script.run(ICauldronV4(address(cauldron)));
        }

        cauldron.setRewarder(rewarder);

        vm.startPrank(whale);
        ICauldronV4(0x5698135CA439f21a57bDdbe8b582C62f090406D5).removeCollateral(whale, 350_000 ether);
        degenBox.setMasterContractApproval(whale, address(cauldron.masterContract()), true, 0, bytes32(0), bytes32(0));
        vm.stopPrank();

        address mimWhale = 0x30dF229cefa463e991e29D42DB0bae2e122B2AC7;
        vm.startPrank(mimWhale);
        mim.transfer(address(degenBox), 50_000 ether);
        degenBox.deposit(mim, address(degenBox), address(cauldron), 50_000 ether, 0);
        vm.stopPrank();

        vm.prank(distributorOwner);
        distributor.setCauldronParameters(ICauldronV4(address(cauldron)), 4000, 1000 ether, rewarder);
        distributor.distribute();
        advanceTime(1 weeks);
        _generateRewards(5_000 ether);
    }

    function testPositionOpening() public {
        vm.startPrank(whale);
        vm.expectCall(address(rewarder), abi.encodeCall(rewarder.deposit, (whale, 350_000 ether)));
        cauldron.addCollateral(whale, false, 350_000 ether);
        vm.stopPrank();
        (uint256 amount, int256 debt) = rewarder.userInfo(whale);
        assertEq(amount, 350_000 ether);
    }

    function testPositionClosing() public {
        vm.startPrank(whale);
        cauldron.addCollateral(whale, false, 350_000 ether);
        vm.expectCall(address(rewarder), abi.encodeCall(rewarder.withdraw, (whale, 350_000 ether)));
        cauldron.removeCollateral(whale, 350_000 ether);
        vm.stopPrank();
        (uint256 amount, int256 debt) = rewarder.userInfo(whale);
        assertEq(amount, 0 ether);
    }

    function testPositionRepayment() public {
        vm.startPrank(whale);
        cauldron.addCollateral(whale, false, 350_000 ether);
        cauldron.borrow(whale, 50_000 ether);
        vm.stopPrank();
        distributor.distribute();
        assertEq(rewarder.pendingReward(whale), 4904175222492799999999);
        vm.expectCall(address(cauldron), abi.encodeCall(cauldron.repay, (whale, true, 4904175222492799999999)));
        rewarder.harvest(whale);
        assertLt(cauldron.userBorrowPart(whale), 45_100 ether);
        assertEq(rewarder.pendingReward(whale), 0);
    }

    /*
    // any excess should be distributed to fee collector
    function testFeeCollection() public {
        address feeCollector = distributor.feeCollector();
        
        vm.startPrank(distributorOwner);
        distributor.setFeeParameters(feeCollector, CauldronLib.getInterestPerSecond(1000));
        vm.stopPrank();
        
        CauldronMock cauldron1 = new CauldronMock(mim);
        cauldron1.setOraclePrice(1e18);

        _generateRewards(1_000 ether);

        vm.prank(distributorOwner);
        distributor.setCauldronParameters(ICauldronV4(address(cauldron1)), 5000, 1000 ether, IRewarder(address(0)));
        cauldron1.setTotalCollateralShare(1_000 ether);
        
        uint256 mimBalanceBefore = mim.balanceOf(feeCollector);

        distributor.distribute();
        
        advanceTime(1 weeks);
        distributor.distribute();
        assertEq(mim.balanceOf(address(distributor)), 0);
        assertEq(mim.balanceOf(feeCollector) - mimBalanceBefore, 990410958904109645440);
    }
    */

    function _generateRewards(uint256 amount) public {
        address mimWhale = 0x30dF229cefa463e991e29D42DB0bae2e122B2AC7;
        vm.startPrank(mimWhale);
        mim.transfer(address(distributor), amount);
        vm.stopPrank();
    }
}
