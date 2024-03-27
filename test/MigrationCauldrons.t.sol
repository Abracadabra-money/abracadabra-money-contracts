// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/MigrationCauldrons.s.sol";
import {CauldronTestLib} from "./utils/CauldronTestLib.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {BoringOwnable} from "BoringSolidity/BoringOwnable.sol";

contract MigrationCauldronsTest is BaseTest {
    using SafeTransferLib for address;
    MigrationCauldronsScript script;

    function setUp() public override {
        fork(ChainId.Mainnet, 19520183);
        super.setUp();

        script = new MigrationCauldronsScript();
        script.setTesting(true);
        script.deploy();
    }

    function testBorrow() public {
        Deployement[] memory deployement = script.getDeployments();
        uint topUpAmount = 100_000_000 ether;

        for (uint256 i = 0; i < deployement.length; i++) {
            Deployement memory d = deployement[i];
            uint256 decimals = d.decimals;

            console2.log("-> %s", d.name);

            ICauldronV2 cauldron = ICauldronV2(d.cauldron);
            ICauldronV2 masterContract = ICauldronV2(d.cauldron).masterContract();
            IBentoBoxV1 box = IBentoBoxV1(cauldron.bentoBox());

            pushPrank(BoringOwnable(address(masterContract)).owner());
            box.whitelistMasterContract(address(masterContract), true);

            address mim = address(cauldron.magicInternetMoney());
            deal(mim, address(alice), topUpAmount, true);

            pushPrank(alice);
            mim.safeTransfer(address(box), topUpAmount);
            box.deposit(IERC20(mim), address(box), address(d.cauldron), topUpAmount, 0);
            deal(d.token, alice, 100 * (10 ** decimals), true);

            CauldronTestLib.depositAndBorrow(
                box,
                ICauldronV2(d.cauldron),
                address(masterContract),
                IERC20(d.token),
                alice,
                100 * (10 ** decimals),
                50
            );
            popPrank();
        }
    }
}
