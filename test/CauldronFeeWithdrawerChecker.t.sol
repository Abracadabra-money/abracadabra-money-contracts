// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "interfaces/ICauldronV2.sol";
import "periphery/CauldronFeeWithdrawer.sol";

contract CauldronFeeWithdrawerCheckerTestBase is BaseTest {}

contract CauldronFeeWithdrawerCheckerMainnetTest is CauldronFeeWithdrawerCheckerTestBase {
    function xtest() onlyProfile("ci") public {
        fork(ChainId.Mainnet, 17442774);

        super.setUp();
        pushPrank(BoringOwnable(0xC4113Ae18E0d3213c6a06947a2fFC70AD3517c77).owner());
        ICauldronV2(0xC4113Ae18E0d3213c6a06947a2fFC70AD3517c77).setFeeTo(constants.getAddress("cauldronFeeWithdrawer", block.chainid));
        popPrank();

        CauldronFeeWithdrawer withdrawer = CauldronFeeWithdrawer(constants.getAddress("cauldronFeeWithdrawer", block.chainid));
        withdrawer.withdraw();
    }
}

contract CauldronFeeWithdrawerCheckerAvalancheTest is CauldronFeeWithdrawerCheckerTestBase {
    function xtest() onlyProfile("ci") public {
        fork(ChainId.Avalanche, Block.Latest);

        super.setUp();

        pushPrank(BoringOwnable(0xc568a699c5B43A0F1aE40D3254ee641CB86559F4).owner());
        ICauldronV2(0xc568a699c5B43A0F1aE40D3254ee641CB86559F4).setFeeTo(constants.getAddress("cauldronFeeWithdrawer", block.chainid));
        popPrank();

        CauldronFeeWithdrawer withdrawer = CauldronFeeWithdrawer(constants.getAddress("cauldronFeeWithdrawer", block.chainid));
        withdrawer.withdraw();
    }
}

contract CauldronFeeWithdrawerCheckerArbitrumTest is CauldronFeeWithdrawerCheckerTestBase {
    function xtest() onlyProfile("ci") public {
        super.setUp();
        fork(ChainId.Arbitrum, Block.Latest);
        CauldronFeeWithdrawer withdrawer = CauldronFeeWithdrawer(constants.getAddress("cauldronFeeWithdrawer", block.chainid));
        withdrawer.withdraw();
    }
}

contract CauldronFeeWithdrawerCheckerFantomTest is CauldronFeeWithdrawerCheckerTestBase {
    function test() onlyProfile("ci") public {
        fork(ChainId.Fantom, 63819499);
        super.setUp();
        CauldronFeeWithdrawer withdrawer = CauldronFeeWithdrawer(constants.getAddress("multichainWithdrawer", block.chainid));
        withdrawer.withdraw();
    }
}
