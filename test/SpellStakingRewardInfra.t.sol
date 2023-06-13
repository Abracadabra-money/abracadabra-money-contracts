// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "BoringSolidity/BoringOwnable.sol";
import "libraries/SafeApprove.sol";
import "script/SpellStakingRewardInfra.s.sol";

contract SpellStakingRewardInfraTestBase is BaseTest {
    using BoringERC20 for IERC20;
    using SafeApprove for IERC20;

    CauldronFeeWithdrawer withdrawer;
    SpellStakingRewardDistributor distributor;

    address public mimWhale;

    function initialize(uint256 chainId, uint256 blockNumber, address _mimWhale) public returns (SpellStakingRewardInfraScript script) {
        fork(chainId, blockNumber);
        super.setUp();

        mimWhale = _mimWhale;

        script = new SpellStakingRewardInfraScript();
        script.setTesting(true);
    }

    function afterDeployed() public {
        pushPrank(withdrawer.owner());
        CauldronInfo[] memory cauldronInfos = constants.getCauldrons(constants.getChainName(block.chainid), true, this._cauldronPredicate);
        address[] memory cauldrons = new address[](cauldronInfos.length);
        uint8[] memory versions = new uint8[](cauldronInfos.length);
        bool[] memory enabled = new bool[](cauldronInfos.length);

        for (uint256 i = 0; i < cauldronInfos.length; i++) {
            CauldronInfo memory cauldronInfo = cauldronInfos[i];
            cauldrons[i] = cauldronInfo.cauldron;
            versions[i] = cauldronInfo.version;
            enabled[i] = true;
        }
        withdrawer.setCauldrons(cauldrons, versions, enabled);
        popPrank();

        uint256 cauldronCount = withdrawer.cauldronInfosCount();
        IERC20 mim = withdrawer.mim();

        pushPrank(withdrawer.mimProvider());
        mim.safeApprove(address(withdrawer), type(uint256).max);
        popPrank();

        for (uint256 i = 0; i < cauldronCount; i++) {
            (, address masterContract, , ) = withdrawer.cauldronInfos(i);
            address owner = BoringOwnable(masterContract).owner();
            vm.prank(owner);
            ICauldronV1(masterContract).setFeeTo(address(withdrawer));
        }
    }

    function _cauldronPredicate(address, bool, uint8, string memory, uint256 creationBlock) external view returns (bool) {
        return creationBlock <= block.number;
    }

    function testWithdraw() public {
        // deposit fund into each registered bentoboxes
        vm.startPrank(mimWhale);
        address mimWithdrawRecipient = withdrawer.mimWithdrawRecipient();
        uint256 cauldronCount = withdrawer.cauldronInfosCount();
        uint256 totalFeeEarned;
        IERC20 mim = withdrawer.mim();
        uint256 mimBefore = mim.balanceOf(address(mimWithdrawRecipient));

        for (uint256 i = 0; i < cauldronCount; i++) {
            (address cauldron, , , uint8 version) = withdrawer.cauldronInfos(i);
            uint256 feeEarned;

            ICauldronV1(cauldron).accrue();

            if (version == 1) {
                (, feeEarned) = ICauldronV1(cauldron).accrueInfo();
            } else if (version >= 2) {
                (, feeEarned, ) = ICauldronV2(cauldron).accrueInfo();
            }

            totalFeeEarned += feeEarned;
        }

        vm.expectEmit(false, false, false, false);
        emit CauldronFeeWithdrawWithdrawerEvents.LogMimTotalWithdrawn(0);
        withdrawer.withdraw();

        uint256 mimAfter = mim.balanceOf(address(mimWithdrawRecipient));
        assertGe(mimAfter, mimBefore);
    }
}

contract MainnetSpellStakingInfraTest is SpellStakingRewardInfraTestBase {
    function setUp() public override {
        SpellStakingRewardInfraScript script = super.initialize(ChainId.Mainnet, 17470779, 0x5f0DeE98360d8200b20812e174d139A1a633EDd2);
        (withdrawer, distributor) = script.deploy();
        super.afterDeployed();
    }
}

contract AvalancheSpellStakingInfraTest is SpellStakingRewardInfraTestBase {
    function setUp() public override {
        SpellStakingRewardInfraScript script = super.initialize(ChainId.Avalanche, 31275748, 0xae64A325027C3C14Cf6abC7818aA3B9c07F5C799);
        (withdrawer, distributor) = script.deploy();
        super.afterDeployed();
    }
}

contract ArbitrumSpellStakingInfraTest is SpellStakingRewardInfraTestBase {
    function setUp() public override {
        SpellStakingRewardInfraScript script = super.initialize(ChainId.Arbitrum, 100723897, 0x27807dD7ADF218e1f4d885d54eD51C70eFb9dE50);
        (withdrawer, distributor) = script.deploy();
        super.afterDeployed();
    }
}

contract FantomSpellStakingInfraTest is SpellStakingRewardInfraTestBase {
    function setUp() public override {
        SpellStakingRewardInfraScript script = super.initialize(ChainId.Fantom, 64037485, 0x6f86e65b255c9111109d2D2325ca2dFc82456efc);
        (withdrawer, distributor) = script.deploy();
        super.afterDeployed();
    }
}
