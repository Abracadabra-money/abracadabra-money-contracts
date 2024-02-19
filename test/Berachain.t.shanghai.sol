// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/Berachain.s.shanghai.sol";
import {ERC20} from "BoringSolidity/ERC20.sol";

contract BerachainTest_Disable is BaseTest {
    //using SafeTransferLib for address;

    ISwapperV2 swapper;
    ILevSwapperV2 levSwapper;

    address lp;

    function setUp() public override {
        fork(ChainId.Bera, 56035);
        super.setUp();

        BerachainScript script = new BerachainScript();
        script.setTesting(true);

        (swapper, levSwapper) = script.deploy();

        lp = toolkit.getAddress(block.chainid, "bex.token.mimhoney");
    }

    function test1() public {
        fork(ChainId.Bera, 91302);
        uint256 amount = ERC20(0x2dd5691de6528854c60fd67dA57AD185f6D1666d).balanceOf(0x498B823149E6aB864DfCE2c7C44e1292a74b1bC7);
        console2.log(amount);
    }

    function test2() public {
        fork(ChainId.Bera, 63813);
        pushPrank(0x498B823149E6aB864DfCE2c7C44e1292a74b1bC7);
        address(0x6aBD7831C3a00949dabCE4cCA74B4B6B327d6C26).call{value: 0}(
            hex"656f3d640000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001e000000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000014000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000001e000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000500000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000014000000000000000000000000000000000000000000000000000000000000001c00000000000000000000000000000000000000000000000000000000000000220000000000000000000000000000000000000000000000000000000000000044000000000000000000000000000000000000000000000000000000000000000800000000000000000000000002dd5691de6528854c60fd67da57ad185f6d1666d0000000000000000000000006abd7831c3a00949dabce4cca74b4b6b327d6c260000000000000000000000000000000000000000000000008ac7230489e8000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe000000000000000000000000498b823149e6ab864dfce2c7c44e1292a74b1bc70000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000034bc4fdde27c0000000000000000000000000000d6b8bd85a9593cb47c8c15c95bbf3e593c5dc5910000000000000000000000000000000000000000000000000000000000000200000000000000000000000000d6b8bd85a9593cb47c8c15c95bbf3e593c5dc59100000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000124b691d78c000000000000000000000000498b823149e6ab864dfce2c7c44e1292a74b1bc7000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000034bc4fdde27c000000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000080000000000000000000000000b734c264f83e39ef6ec200f99550779998cc812d000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe000000000000000000000000498b823149e6ab864dfce2c7c44e1292a74b1bc70000000000000000000000000000000000000000000000000000000000000000"
        );
        popPrank();
    }
}
