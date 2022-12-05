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

    function resetRepay() external {
        amountRepaid = 0;
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
        (distributor) = script.run();

        mim = ERC20(constants.getAddress("arbitrum.mim"));
        harvestor = GlpWrapperHarvestor(0xf9cE23237B25E81963b500781FA15d6D38A0DE62);
        vm.startPrank(harvestor.owner());
        harvestor.setDistributor(distributor);

        distributorOwner = distributor.owner();
        vm.stopPrank();
    }

    function testOneCauldronWith50PercentApy() public {
        CauldronMock cauldron1 = new CauldronMock(mim);
        cauldron1.setOraclePrice(1e18);

        _generateRewards(1_000 ether);
        distributor.distribute();

        assertEq(cauldron1.amountRepaid(), 0);
        assertEq(mim.balanceOf(address(distributor)), 1_000 ether);

        vm.prank(distributorOwner);
        distributor.setCauldronParameters(ICauldronV4(address(cauldron1)), 5000);

        MimCauldronDistributor.CauldronInfo memory info1 = distributor.getCauldronInfo(0);
        assertEq(info1.lastDistribution, block.timestamp);

        advanceTime(1 weeks);
        distributor.distribute();

        info1 = distributor.getCauldronInfo(0);
        uint256 timestamp = block.timestamp;

        // should not get anything since totalCollateralShare is 0
        assertEq(info1.lastDistribution, timestamp);
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
    }

    function _generateRewards(uint256 amount) public {
        address mimWhale = 0x30dF229cefa463e991e29D42DB0bae2e122B2AC7;
        vm.startPrank(mimWhale);
        mim.transfer(address(distributor), amount);
        vm.stopPrank();
    }
}
