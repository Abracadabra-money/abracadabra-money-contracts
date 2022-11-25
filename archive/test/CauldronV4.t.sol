// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "BoringSolidity/ERC20.sol";
import "BoringSolidity/libraries/BoringRebase.sol";
import "utils/BaseTest.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/IOracle.sol";
import "interfaces/IWETH.sol";
import "cauldrons/CauldronV4.sol";
import "utils/CauldronLib.sol";
import "periphery/DegenBoxOwner.sol";

contract CauldronV4Test is BaseTest {
    using RebaseLibrary for Rebase;
    event LogStrategyQueued(IERC20 indexed token, IStrategy indexed strategy);

    uint8 internal constant ACTION_CALL = 30;
    IBentoBoxV1 public degenBox;
    ICauldronV4 public cauldron;
    DegenBoxOwner degenBoxOwner;
    CauldronV4 public masterContract;
    ERC20 public mim;
    ERC20 public weth;

    function setUp() public override {
        forkMainnet(15998564);
        super.setUp();

        degenBox = IBentoBoxV1(constants.getAddress("mainnet.degenBox"));
        masterContract = new CauldronV4(degenBox, IERC20(constants.getAddress("mainnet.mim")));
        degenBoxOwner = new DegenBoxOwner();
        deployer = payable(address(this));

        vm.startPrank(degenBoxOwner.owner());
        degenBoxOwner.setDegenBox(degenBox);
        vm.stopPrank();

        degenBox = IBentoBoxV1(constants.getAddress("mainnet.degenBox"));
        mim = ERC20(constants.getAddress("mainnet.mim"));
        weth = ERC20(constants.getAddress("mainnet.weth"));

        vm.startPrank(degenBox.owner());
        degenBox.whitelistMasterContract(address(masterContract), true);
        cauldron = CauldronLib.deployCauldronV4(
            degenBox,
            address(masterContract),
            weth,
            IOracle(0x6C86AdB5696d2632973109a337a50EF7bdc48fF1),
            "",
            7000, // 70% ltv
            200, // 2% interests
            200, // 2% opening
            800 // 8% liquidation
        );

        vm.stopPrank();

        address mimWhale = 0xbbc4A8d076F4B1888fec42581B6fc58d242CF2D5;
        vm.startPrank(mimWhale);
        mim.approve(address(degenBox), type(uint256).max);
        degenBox.deposit(mim, mimWhale, address(cauldron), 10_000_000 ether, 0);
        vm.stopPrank();
    }

    function testDefaultBlacklistedCallees() public {
        bytes memory callData = abi.encode(
            IBentoBoxV1.balanceOf.selector,
            constants.getAddress("mainnet.mim"),
            0xfB3485c2e209A5cfBDC1447674256578f1A80eE3
        );
        uint8[] memory actions = new uint8[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory datas = new bytes[](1);

        actions[0] = ACTION_CALL;
        values[0] = 0;
        datas[0] = abi.encode(address(degenBox), callData, false, false, uint8(0));

        vm.expectRevert("Cauldron: can't call");
        cauldron.cook(actions, values, datas);

        datas[0] = abi.encode(address(cauldron), callData, false, false, uint8(0));
        vm.expectRevert("Cauldron: can't call");
        cauldron.cook(actions, values, datas);

        datas[0] = abi.encode(address(degenBox.owner()), callData, false, false, uint8(0));
        vm.expectRevert("Cauldron: can't call");
        cauldron.cook(actions, values, datas);
    }

    function testCannotChangeDegenBoxAndCauldronBlacklisting() public {
        vm.startPrank(masterContract.owner());
        vm.expectRevert("invalid callee");
        cauldron.setBlacklistedCallee(address(degenBox), false);
        vm.expectRevert("invalid callee");
        cauldron.setBlacklistedCallee(address(cauldron), false);
    }

    function testCustomBlacklistedCallee() public {
        // some random proxy oracle
        address callee = 0x6C86AdB5696d2632973109a337a50EF7bdc48fF1;

        bytes memory callData = abi.encode(IOracle.peekSpot.selector, "");
        uint8[] memory actions = new uint8[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory datas = new bytes[](1);

        actions[0] = ACTION_CALL;
        values[0] = 0;
        datas[0] = abi.encode(callee, callData, false, false, uint8(0));

        cauldron.cook(actions, values, datas);

        vm.prank(masterContract.owner());
        cauldron.setBlacklistedCallee(callee, true);

        vm.expectRevert("Cauldron: can't call");
        cauldron.cook(actions, values, datas);

        vm.prank(masterContract.owner());
        cauldron.setBlacklistedCallee(callee, false);
        cauldron.cook(actions, values, datas);
    }

    function testRepayForAll() public {
        uint256 aliceBorrowAmount = _depositAndBorrow(alice, 10 ether, 60);
        console2.log("alice borrows", aliceBorrowAmount);
        _advanceInterests(30 days);
        int256 aliceDebt = _getUserDebt(alice, aliceBorrowAmount);

        uint256 bobBorrowAmount = _depositAndBorrow(bob, 32 ether, 60);
        console2.log("bob borrows", bobBorrowAmount);
        int256 bobDebt = _getUserDebt(bob, bobBorrowAmount);

        console2.log("alice debt before");
        console.logInt(aliceDebt / 1 ether);
        console2.log("bob debt before");
        console.logInt(bobDebt / 1 ether);

        address mimWhale = 0xbbc4A8d076F4B1888fec42581B6fc58d242CF2D5;
        vm.prank(mimWhale);
        mim.transfer(address(cauldron), 100 ether);
        uint128 repaidAmount = cauldron.repayForAll(0, true);
        console2.log("repaid amount", repaidAmount);

        int256 aliceDebtAfter = _getUserDebt(alice, aliceBorrowAmount);
        int256 bobDebtAfter = _getUserDebt(bob, bobBorrowAmount);
        console2.log("alice debt after");
        console.logInt(aliceDebtAfter / 1 ether);
        console2.log("bob debt after");
        console.logInt(bobDebtAfter / 1 ether);

        assertLt(aliceDebtAfter, aliceDebt);
        assertLt(bobDebtAfter, bobDebt);

        _advanceInterests(45 days);

        aliceDebt = _getUserDebt(alice, aliceBorrowAmount);
        bobDebt = _getUserDebt(bob, bobBorrowAmount);

        console2.log("alice debt before");
        console.logInt(aliceDebt / 1 ether);
        console2.log("bob debt before");
        console.logInt(bobDebt / 1 ether);

        vm.startPrank(mimWhale);
        mim.approve(address(degenBox), type(uint256).max);
        degenBox.setMasterContractApproval(mimWhale, address(masterContract), true, 0, 0, 0);
        degenBox.deposit(mim, mimWhale, mimWhale, 100 ether, 0);
        repaidAmount = cauldron.repayForAll(100 ether, false);
        console2.log("repaid amount", repaidAmount);
        vm.stopPrank();

        aliceDebtAfter = _getUserDebt(alice, aliceBorrowAmount);
        bobDebtAfter = _getUserDebt(bob, bobBorrowAmount);
        console2.log("alice debt after");
        console.logInt(aliceDebtAfter / 1 ether);
        console2.log("bob debt after");
        console.logInt(bobDebtAfter / 1 ether);
    }

    function testDegenBoxOwner() public {
        vm.startPrank(degenBox.owner());
        degenBox.transferOwnership(address(degenBoxOwner), true, false);
        vm.stopPrank();

        vm.startPrank(deployer);
        degenBoxOwner.setOperator(alice, true);

        IBentoBoxV1 prevBox = degenBoxOwner.degenBox();
        degenBoxOwner.setDegenBox(IBentoBoxV1(address(0)));
        assertEq(address(degenBoxOwner.degenBox()), address(0));
        degenBoxOwner.setDegenBox(prevBox);
        assertEq(address(degenBoxOwner.degenBox()), address(prevBox));

        vm.stopPrank();

        bytes memory err = abi.encodeWithSignature("ErrNotOperator(address)", bob);
        bytes memory err2 = abi.encodeWithSignature("ErrNotStrategyRebalancer(address)", bob);

        vm.startPrank(bob);
        vm.expectRevert(err);
        degenBoxOwner.setStrategyTargetPercentage(IERC20(address(0)), 0);
        vm.expectRevert(err2);
        degenBoxOwner.setStrategyTargetPercentageAndRebalance(IERC20(address(0)), 0);
        vm.expectRevert(err);
        degenBoxOwner.setStrategy(IERC20(address(0)), IStrategy(address(0)));
        vm.expectRevert(err);
        degenBoxOwner.whitelistMasterContract(address(0), true);
        vm.expectRevert("Ownable: caller is not the owner");
        degenBoxOwner.setOperator(address(0), true);
        vm.expectRevert("Ownable: caller is not the owner");
        degenBoxOwner.setDegenBox(IBentoBoxV1(address(0)));
        vm.expectRevert("Ownable: caller is not the owner");
        degenBoxOwner.transferDegenBoxOwnership(bob);
        vm.expectRevert("Ownable: caller is not the owner");
        degenBoxOwner.execute(address(0), 0, "");
        vm.stopPrank();

        vm.startPrank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        degenBoxOwner.execute(address(0), 0, "");

        IERC20 lusd = IERC20(constants.getAddress("mainnet.liquity.lusd"));
        (, uint64 targetPercentage, uint128 balance) = degenBox.strategyData(lusd);
        console2.log(targetPercentage, balance);
        assertGt(targetPercentage, 0);
        assertGt(balance, 0);

        // only set strat %
        degenBoxOwner.setStrategyTargetPercentage(lusd, 0);
        (, uint256 targetPercentageAfter, uint256 balanceAfter) = degenBox.strategyData(lusd);
        assertEq(targetPercentageAfter, 0);
        assertEq(balance, balanceAfter);

        vm.expectEmit(true, true, true, true);
        emit LogStrategyQueued(lusd, IStrategy(address(0)));
        degenBoxOwner.setStrategy(lusd, IStrategy(address(0)));

        // whitelist some random address
        degenBoxOwner.whitelistMasterContract(bob, true);
        assertEq(degenBox.whitelistedMasterContracts(bob), true);
        vm.stopPrank();

        vm.startPrank(deployer);
        degenBoxOwner.transferDegenBoxOwnership(bob);
        vm.expectRevert("Ownable: caller is not the owner");
        degenBoxOwner.setStrategy(lusd, IStrategy(address(0)));

        degenBoxOwner.transferOwnership(bob, true, false);
        vm.expectRevert("Ownable: caller is not the owner");
        degenBoxOwner.setOperator(carol, true);
        vm.stopPrank();

        vm.startPrank(degenBoxOwner.owner());
        degenBoxOwner.setStrategyRebalancer(carol, true);
        vm.stopPrank();

        vm.startPrank(degenBox.owner());
        degenBox.transferOwnership(address(degenBoxOwner), true, false);
        vm.stopPrank();

        vm.startPrank(carol);
        // set strat % and rebalance as well
        degenBoxOwner.setStrategyTargetPercentageAndRebalance(lusd, 0);
        (, targetPercentageAfter, balanceAfter) = degenBox.strategyData(lusd);
        assertEq(targetPercentageAfter, 0);
        assertLt(balanceAfter, balance);

        // return to previous strat % and rebalance
        degenBoxOwner.setStrategyTargetPercentageAndRebalance(lusd, targetPercentage);
        (, targetPercentageAfter, balanceAfter) = degenBox.strategyData(lusd);
        assertEq(targetPercentageAfter, targetPercentage);
        assertEq(balanceAfter, balance);
        vm.stopPrank();
    }

    function _advanceInterests(uint256 time) private {
        advanceTime(time);
        cauldron.accrue();
    }

    function _getUserDebt(address account, uint256 borrowAmount) public view returns (int256) {
        Rebase memory totalBorrow = cauldron.totalBorrow();
        uint256 part = cauldron.userBorrowPart(account);
        uint256 amount = totalBorrow.toElastic(part, true);

        return int256(amount) - int256(borrowAmount);
    }

    function _depositAndBorrow(
        address account,
        uint256 amount,
        uint256 percentBorrow
    ) private returns (uint256 borrowAmount) {
        vm.startPrank(account);
        degenBox.setMasterContractApproval(account, address(masterContract), true, 0, 0, 0);

        IWETH(address(weth)).deposit{value: amount}();

        weth.approve(address(degenBox), amount);
        (, uint256 share) = degenBox.deposit(weth, account, account, amount, 0);
        cauldron.addCollateral(account, false, share);

        uint256 price = cauldron.oracle().peekSpot("");
        amount = (1e18 * amount) / price;
        borrowAmount = (amount * percentBorrow) / 100;
        cauldron.borrow(account, borrowAmount);

        degenBox.withdraw(mim, account, account, 0, degenBox.balanceOf(mim, account));
        assertEq(degenBox.balanceOf(mim, account), 0);
        vm.stopPrank();
    }

    function _repay(address account, uint256 amount) private {
        address mimWhale = 0xbbc4A8d076F4B1888fec42581B6fc58d242CF2D5;
        vm.startPrank(mimWhale);
        mim.approve(address(degenBox), type(uint256).max);
        degenBox.deposit(mim, mimWhale, account, amount, 0);
        vm.stopPrank();

        vm.startPrank(account);
        cauldron.repay(account, false, amount);
        vm.stopPrank();
    }

    function _repayAllAndRemoveCollateral(address account) private returns (uint256 repaidAmount) {
        uint256 borrowPart = cauldron.userBorrowPart(account);
        uint256 repayAmount = cauldron.totalBorrow().toElastic(borrowPart, true);
        uint256 collateralShare = cauldron.userCollateralShare(account);

        address mimWhale = 0xbbc4A8d076F4B1888fec42581B6fc58d242CF2D5;
        vm.startPrank(mimWhale);
        mim.approve(address(degenBox), type(uint256).max);
        degenBox.deposit(mim, mimWhale, account, repayAmount, 0);
        vm.stopPrank();

        vm.startPrank(account);
        repaidAmount = cauldron.repay(account, false, borrowPart);

        cauldron.removeCollateral(account, collateralShare);
        vm.stopPrank();

        assertEq(cauldron.userCollateralShare(account), 0);
        assertEq(cauldron.userBorrowPart(account), 0);
    }
}
