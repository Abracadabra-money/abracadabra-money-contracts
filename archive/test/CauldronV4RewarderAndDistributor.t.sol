// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/MimCauldronDistributorV4.s.sol";
import "script/CauldronV4WithRewarder.s.sol";
import "script/CauldronRewarder.s.sol";
import "periphery/GlpWrapperHarvestor.sol";
import "utils/CauldronDeployLib.sol";
import "mocks/OracleMock.sol";

contract CauldronV4RewarderAndDistributorTest is BaseTest {
    MimCauldronDistributor distributor;
    GlpWrapperHarvestor harvestor;
    CauldronV4WithRewarder cauldron;
    CauldronRewarder rewarder;
    ERC20 mim;
    address distributorOwner;
    address constant whale = 0xADeED59F446cb0a141837e8f7c22710d759Cba65;
    IBentoBoxV1 degenBox;
    OracleMock oracleMock;

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
            (, cauldron) = script.run();
        }

        degenBox = cauldron.bentoBox();

        vm.startPrank(degenBox.owner());
        degenBox.whitelistMasterContract(address(cauldron.masterContract()), true);
        vm.stopPrank();

        {
            CauldronRewarderScript script = new CauldronRewarderScript();
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

        oracleMock = new OracleMock();
        oracleMock.setPrice(766454787091600000);
    }

    function testPositionOpening() public {
        (uint256 amount, int256 debt) = rewarder.userInfo(whale);
        assertEq(amount, 0, "non zero amount");
        assertEq(debt, 0, "non zero amount");
        vm.startPrank(whale);
        vm.expectCall(address(rewarder), abi.encodeCall(rewarder.deposit, (whale, 350_000 ether)));
        cauldron.addCollateral(whale, false, 350_000 ether);
        vm.stopPrank();
        (amount, debt) = rewarder.userInfo(whale);
        assertEq(amount, 350_000 ether);
        assertEq(debt, int256((350_000 ether * rewarder.accRewardPerShare()) / rewarder.ACC_REWARD_PER_SHARE_PRECISION()));
    }

    function testPositionClosing() public {
        address merlin = 0xfddfE525054efaAD204600d00CA86ADb1Cc2ea8a;
        vm.startPrank(whale);
        cauldron.addCollateral(whale, false, 350_000 ether);
        vm.expectCall(address(rewarder), abi.encodeCall(rewarder.withdraw, (whale, 350_000 ether)));
        cauldron.removeCollateral(merlin, 350_000 ether);
        vm.stopPrank();
        (uint256 amount, /*int256 debt*/) = rewarder.userInfo(whale);
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

    function testPositionRepaymentWithCook() public {
        vm.startPrank(whale);
        cauldron.addCollateral(whale, false, 350_000 ether);
        cauldron.borrow(whale, 50_000 ether);
        vm.stopPrank();
        distributor.distribute();
        uint8 ACTION_HARVEST_FROM_REWARDER = 34;
        assertEq(rewarder.pendingReward(whale), 4904175222492799999999);
        vm.expectCall(address(cauldron), abi.encodeCall(cauldron.repay, (whale, true, 4904175222492799999999)));
        uint8[] memory actions = new uint8[](1);
        actions[0] = ACTION_HARVEST_FROM_REWARDER;
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory datas = new bytes[](1);
        datas[0] = abi.encode(whale);
        cauldron.cook(actions, values, datas);
        assertLt(cauldron.userBorrowPart(whale), 45_100 ether);
        assertEq(rewarder.pendingReward(whale), 0);
    }

    function testPositionRepaymentMultipleHarvest() public {
        address merlin = 0xfddfE525054efaAD204600d00CA86ADb1Cc2ea8a;
        vm.startPrank(whale);
        cauldron.addCollateral(whale, false, 250_000 ether);
        cauldron.addCollateral(merlin, false, 100_000 ether);
        cauldron.borrow(whale, 25_000 ether);
        vm.stopPrank();
        vm.prank(merlin);
        cauldron.borrow(merlin, 25_000 ether);
        distributor.distribute();
        assertEq(rewarder.pendingReward(whale), 3502982301780571428571);
        assertEq(rewarder.pendingReward(merlin), 1401192920712228571428);
        vm.expectCall(address(cauldron), abi.encodeCall(cauldron.repay, (whale, true, 3502982301780571428571)));
        cauldron.accrue();
        address[] memory users = new address[](2);
        users[0] = whale;
        users[1] = merlin;
        rewarder.harvestMultiple(users);
        assertLt(cauldron.userBorrowPart(whale), 23_000 ether);
        assertEq(rewarder.pendingReward(whale), 0);
    }

    function testPositionRepaymentOvershoot() public {
        vm.startPrank(whale);
        cauldron.addCollateral(whale, false, 350_000 ether);
        cauldron.borrow(whale, 100 ether);
        vm.stopPrank();
        uint256 mimBalanceBefore = degenBox.balanceOf(mim, whale);
        distributor.distribute();
        assertEq(rewarder.pendingReward(whale), 4999808350444985599999);
        vm.expectCall(address(cauldron), abi.encodeCall(cauldron.repay, (whale, true, 100 ether)));
        rewarder.harvest(whale);
        uint256 mimBalanceAfter = degenBox.balanceOf(mim, whale);
        assertEq(cauldron.userBorrowPart(whale), 0);
        assertEq(mimBalanceAfter - mimBalanceBefore, 4899808350444985599999);
        assertEq(rewarder.pendingReward(whale), 0);
    }

    function testLiquidation() public {
        address merlin = 0xfddfE525054efaAD204600d00CA86ADb1Cc2ea8a;
        vm.startPrank(whale);
        cauldron.addCollateral(whale, false, 21_000 ether);
        cauldron.addCollateral(merlin, false, 21_000 ether);
        cauldron.borrow(whale, 12_500 ether);
        vm.stopPrank();
        vm.prank(merlin);
        cauldron.borrow(merlin, 12_500 ether);
        distributor.distribute();
        _switchOracle();
        address[] memory users = new address[](2);
        users[0] = whale;
        users[1] = merlin;
        uint256[] memory parts = new uint256[](2);
        parts[0] = 12_500 ether;
        parts[1] = 12_500 ether;
        assertEq(rewarder.pendingReward(whale), 2476043805623199999999);
        vm.expectCall(address(cauldron), abi.encodeCall(cauldron.repay, (whale, true, 2476043805623199999999)));
        vm.expectRevert(bytes("Cauldron: all are solvent"));
        cauldron.liquidate(users, parts, address(this), ISwapperV2(address(0)), new bytes(0));
    }

    function _generateRewards(uint256 amount) public {
        address mimWhale = 0x30dF229cefa463e991e29D42DB0bae2e122B2AC7;
        vm.startPrank(mimWhale);
        mim.transfer(address(distributor), amount);
        vm.stopPrank();
    }

    function _switchOracle() public {
        address oracleOwner = ProxyOracle(address(cauldron.oracle())).owner();
        vm.startPrank(oracleOwner);
        ProxyOracle(address(cauldron.oracle())).changeOracleImplementation(oracleMock);
        vm.stopPrank();
    }
}
