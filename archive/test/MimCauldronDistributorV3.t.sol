// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/MimCauldronDistributor.s.sol";
import "periphery/GlpWrapperHarvestor.sol";
import "mocks/OracleMock.sol";

contract BentoBoxMock {
    function toAmount(
        IERC20,
        uint256 share,
        bool
    ) external pure returns (uint256 amount) {
        return share;
    }
}

contract CauldronMock {
    IOracle public immutable oracle;
    bytes public oracleData;
    uint256 public totalCollateralShare;
    uint256 public amountRepaid;
    IBentoBoxV1 public bentoBox;
    Rebase public totalBorrow;
    ERC20 mim;

    constructor(ERC20 _mim) {
        mim = _mim;
        oracle = new OracleMock();
        bentoBox = IBentoBoxV1(address(new BentoBoxMock()));
        totalBorrow.elastic = type(uint128).max;
        totalBorrow.base = type(uint128).max;
    }

    function setOraclePrice(int256 price) external {
        OracleMock(address(oracle)).setPrice(price);
    }

    function setTotalCollateralShare(uint256 _totalCollateralShare) external {
        totalCollateralShare = _totalCollateralShare;
    }

    function setTotalBorrow(uint128 elastic, uint128 base) external {
        totalBorrow.elastic = elastic;
        totalBorrow.base = base;
    }

    function collateral() external pure returns (IERC20) {
        return IERC20(address(0));
    }

    function repayForAll(uint128 amount, bool skim) public returns (uint128) {
        if (skim) {
            amount = uint128(mim.balanceOf(address(this)));
        }

        mim.transfer(address(0), mim.balanceOf(address(this)));
        amountRepaid += amount;
        return amount;
    }
}

contract MimCauldronDistributorTest is BaseTest {
    MimCauldronDistributor distributor;
    GlpWrapperHarvestor harvestor;
    ERC20 mim;
    address distributorOwner;

    function setUp() public override {
        forkArbitrum(43803834);
        super.setUp();

        MimCauldronDistributorScript script = new MimCauldronDistributorScript();
        script.setTesting(true);
        (distributor) = script.deploy();

        mim = ERC20(constants.getAddress("arbitrum.mim"));
        harvestor = GlpWrapperHarvestor(0xf9cE23237B25E81963b500781FA15d6D38A0DE62);
        vm.startPrank(harvestor.owner());
        harvestor.setDistributor(distributor);

        distributorOwner = distributor.owner();
        vm.stopPrank();

        address feeCollector = distributor.feeCollector();
        vm.prank(distributorOwner);
        distributor.setFeeParameters(feeCollector, 0);
    }

    function testIdealDistribution() public {
        CauldronMock cauldron1 = new CauldronMock(mim);
        cauldron1.setOraclePrice(1e18);

        _generateRewards(1_000 ether);
        distributor.distribute();

        assertEq(cauldron1.amountRepaid(), 0);
        assertEq(mim.balanceOf(address(distributor)), 1_000 ether);

        vm.prank(distributorOwner);
        distributor.setCauldronParameters(ICauldronV4(address(cauldron1)), 5000, 1000 ether);

        (, , uint64 lastDistribution, , , , , ) = distributor.cauldronInfos(0);
        assertEq(lastDistribution, block.timestamp);

        advanceTime(1 weeks);
        distributor.distribute();

        (, , lastDistribution, , , , , ) = distributor.cauldronInfos(0);
        uint256 timestamp = block.timestamp;

        // should not get anything since totalCollateralShare is 0
        assertEq(lastDistribution, timestamp);
        assertEq(cauldron1.amountRepaid(), 0);
        assertEq(mim.balanceOf(address(distributor)), 1_000 ether);

        cauldron1.setTotalCollateralShare(1_000 ether);

        // time elapsed is 0
        distributor.distribute();

        assertEq(cauldron1.amountRepaid(), 0);
        assertEq(mim.balanceOf(address(distributor)), 1_000 ether);

        // - cauldron apy is 50%, 500 mim per year
        // - 1000 mim in distributor
        // - 1 week passed
        // - around 9.59 MIM distribution
        advanceTime(1 weeks);
        distributor.distribute();
        assertEq(cauldron1.amountRepaid(), 9589041095890354560);
        assertEq(mim.balanceOf(address(distributor)), 990410958904109645440);
        timestamp = block.timestamp;

        // should't distribute anything more from calling a second time
        distributor.distribute();
        (, , lastDistribution, , , , , ) = distributor.cauldronInfos(0);
        assertEq(cauldron1.amountRepaid(), 9589041095890354560);
        assertEq(mim.balanceOf(address(distributor)), 990410958904109645440);
        assertEq(lastDistribution, timestamp);

        advanceTime(1 weeks);
        distributor.distribute();
        assertEq(cauldron1.amountRepaid(), 19178082191780709120);
        assertEq(mim.balanceOf(address(distributor)), 980821917808219290880);
        timestamp = block.timestamp;

        advanceTime(1 weeks);

        // a new cauldron is registered with 50% apy as well
        CauldronMock cauldron2 = new CauldronMock(mim);
        cauldron2.setOraclePrice(1e18);
        vm.prank(distributorOwner);
        distributor.setCauldronParameters(ICauldronV4(address(cauldron2)), 5000, 1000 ether);
        cauldron2.setTotalCollateralShare(1_000 ether);

        assertEq(distributor.getCauldronInfoCount(), 2);
        uint256 timestampCauldron2Added = block.timestamp;

        // distribute, cauldron was just added, shouldn't get anything
        distributor.distribute();
        timestamp = block.timestamp;

        (, , lastDistribution, , , , , ) = distributor.cauldronInfos(0);
        assertEq(cauldron1.amountRepaid(), 28767123287671063680);
        assertEq(mim.balanceOf(address(distributor)), 971232876712328936320);
        assertEq(lastDistribution, timestamp);

        (, , lastDistribution, , , , , ) = distributor.cauldronInfos(1);
        assertEq(cauldron2.amountRepaid(), 0);
        assertEq(lastDistribution, timestampCauldron2Added);

        advanceTime(1 weeks);
        timestamp = block.timestamp;
        distributor.distribute();

        (, , lastDistribution, , , , , ) = distributor.cauldronInfos(0);
        assertEq(cauldron1.amountRepaid(), 38356164383561418240);
        assertEq(mim.balanceOf(address(distributor)), 952054794520548227200);
        assertEq(lastDistribution, timestamp);

        (, , lastDistribution, , , , , ) = distributor.cauldronInfos(1);
        assertEq(cauldron2.amountRepaid(), 9589041095890354560);
        assertEq(lastDistribution, timestamp);
    }

    function testStarvingDistributionSharing() public {
        CauldronMock cauldron1 = new CauldronMock(mim);
        CauldronMock cauldron2 = new CauldronMock(mim);
        cauldron1.setOraclePrice(1e18);
        cauldron2.setOraclePrice(1e18);

        vm.startPrank(distributorOwner);
        distributor.setCauldronParameters(ICauldronV4(address(cauldron1)), 5000, 1000 ether);
        distributor.setCauldronParameters(ICauldronV4(address(cauldron2)), 8000, 1000 ether);
        vm.stopPrank();

        // starve the distibutor so it is unable to fullfill the distribution apy
        cauldron1.setTotalCollateralShare(1_000_000 ether);
        cauldron2.setTotalCollateralShare(2_000_000 ether);

        // 200 MIM in the distributor
        // 1 week elapsed
        // cauldron 1 apy is 50%, tvl 1_000_000, 0.00000158% per second
        // cauldron 2 apy is 80%, tvl 2_000_000, 0.00000253% per second
        // 1 week is 604800 seconds
        // 1_000_000 * (0.00000158 / 100) * 604800 = 9589.04 MIM
        // 2_000_000 * (0.00000253 / 100) * 604800 = 30684.93 MIM
        // ideal amount is 40273.97 MIM
        // cauldron 1 effective amount is (9589.04 / 40273.97) * 1_000 =  around 238.09 MIM
        // cauldron 2 effective amount is (30684.93 / 40273.97) * 1_000 = around 761.90 MIM
        _generateRewards(1_000 ether);
        advanceTime(1 weeks);

        distributor.distribute();

        assertEq(cauldron1.amountRepaid(), 238095238095237523156);
        assertEq(cauldron2.amountRepaid(), 761904761904762476843);
        assertApproxEqAbs(mim.balanceOf(address(distributor)), 0, 1 ether);
    }

    // any excess should be distributed to fee collector
    function testFeeCollection() public {
        address feeCollector = distributor.feeCollector();
        vm.prank(distributorOwner);
        distributor.setFeeParameters(feeCollector, 100);

        CauldronMock cauldron1 = new CauldronMock(mim);
        cauldron1.setOraclePrice(1e18);

        _generateRewards(1_000 ether);

        vm.prank(distributorOwner);
        distributor.setCauldronParameters(ICauldronV4(address(cauldron1)), 5000, 1000 ether);
        cauldron1.setTotalCollateralShare(1_000 ether);

        uint256 mimBalanceBefore = mim.balanceOf(feeCollector);

        distributor.distribute();
        advanceTime(1 weeks);
        distributor.distribute();
        assertEq(mim.balanceOf(address(distributor)), 0);

        assertEq(mim.balanceOf(feeCollector) - mimBalanceBefore, 990410958904109645440);
    }

    function _generateRewards(uint256 amount) public {
        address mimWhale = 0x30dF229cefa463e991e29D42DB0bae2e122B2AC7;
        vm.startPrank(mimWhale);
        mim.transfer(address(distributor), amount);
        vm.stopPrank();
    }
}
