// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/CauldronFeeWithdrawer.s.sol";
import "interfaces/IAnyswapRouter.sol";
import "libraries/SafeApprove.sol";

contract AnyswapRouterMock is IAnyswapRouter {
    function anySwapOutUnderlying(
        address token,
        address to,
        uint256 amount,
        uint256 toChainID
    ) external {}

    function anySwapOut(
        address token,
        address to,
        uint256 amount,
        uint256 toChainID
    ) external {}
}

contract CauldronFeeWithdrawerTest is BaseTest {
    event LogOperatorChanged(address indexed operator, bool previous, bool current);
    event LogSwappingRecipientChanged(address indexed recipient, bool previous, bool current);
    event LogAllowedSwapTokenOutChanged(IERC20 indexed token, bool previous, bool current);
    event LogSwapperChanged(address indexed previous, address indexed current);
    event LogMimProviderChanged(address indexed previous, address indexed current);
    event LogMimWithdrawn(IBentoBoxV1 indexed bentoBox, uint256 amount);
    event LogMimTotalWithdrawn(uint256 amount);
    event LogSwapMimTransfer(uint256 amounIn, uint256 amountOut, IERC20 tokenOut);
    event LogBentoBoxChanged(IBentoBoxV1 indexed bentoBox, bool previous, bool current);
    event LogCauldronChanged(address indexed cauldron, bool previous, bool current);
    event LogBridgerChanged(ICauldronFeeBridger indexed previous, ICauldronFeeBridger indexed current);
    event LogBridgeableTokenChanged(IERC20 indexed token, bool previous, bool current);

    CauldronFeeWithdrawer public withdrawer;
    AnyswapRouterMock public anyswapMock;

    address public mimWhale;

    function setUp() public override {
        forkMainnet(15979493);
        super.setUp();

        mimWhale = 0xbbc4A8d076F4B1888fec42581B6fc58d242CF2D5;
        CauldronFeeWithdrawerScript script = new CauldronFeeWithdrawerScript();

        //AnyswapRouterMock anyswapRouterMock = new AnyswapRouterMock();
        //AnyswapCauldronFeeBridger bridger = new AnyswapCauldronFeeBridger(anyswapRouterMock, bob, 1);
        //withdrawer.setBridger(bridger);

        script.setTesting(true);
        withdrawer = script.run();

        uint256 cauldronCount = withdrawer.cauldronInfosCount();
        ERC20 mim = withdrawer.mim();

        vm.startPrank(withdrawer.mimProvider());
        mim.approve(address(withdrawer), type(uint256).max);
        vm.stopPrank();

        for (uint256 i = 0; i < cauldronCount; i++) {
            (, address masterContract, , ) = withdrawer.cauldronInfos(i);

            address owner = BoringOwnable(masterContract).owner();
            vm.prank(owner);
            ICauldronV1(masterContract).setFeeTo(address(withdrawer));
        }
    }

    function testWithdraw() public {
        // deposit fund into each registered bentoboxes
        vm.startPrank(mimWhale);
        uint256 cauldronCount = withdrawer.cauldronInfosCount();
        uint256 totalFeeEarned;
        ERC20 mim = withdrawer.mim();

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

        vm.expectEmit(false, false, false, true);
        emit LogMimTotalWithdrawn(27718150145930853419983);

        console2.log(totalFeeEarned);
        withdrawer.withdraw();
    }
}
