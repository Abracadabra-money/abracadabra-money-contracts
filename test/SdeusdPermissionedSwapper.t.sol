// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/SdeusdPermissionedSwapper.s.sol";
import {IBentoBoxLite} from "/interfaces/IBentoBoxV1.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {ISwapperV2} from "/interfaces/ISwapperV2.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DummySwapper is ISwapperV2 {
    address public immutable box;
    address public immutable deusd;
    constructor(address _box, address _deusd) {
        box = _box;
        deusd = _deusd;
    }

    function swap(address, address, address recipient, uint256, uint256, bytes calldata) external returns (uint256, uint256) {
        IBentoBoxLite(box).withdraw(deusd, address(this), address(recipient), 0, 100 ether);
        return (0, 0);
    }
}

contract SdeusdPermissionedSwapperTest is BaseTest {
    using SafeTransferLib for address;

    error InvalidCooldown(); // From Elixir SDEUSD

    bytes32 private constant COOLDOWN_UNRESTRICTED_STAKER_ROLE = keccak256("COOLDOWN_UNRESTRICTED_STAKER_ROLE");
    address constant SDEUSD_WHALE = 0xCf28710273B55F9dD6D19088eD4B994af560266b;
    address constant SDEUSD_OWNER = 0xD7CDBde6C9DA34fcB2917390B491193b54C24f24;

    SdeusdPermissionedSwapperScript script;
    SdeusdPermissionedSwapper swapper;
    address sdeusd;
    address deusd;
    IBentoBoxLite box;
    address dummySwapper;

    function setUp() public override {
        fork(ChainId.Mainnet, 21366136);
        super.setUp();

        script = new SdeusdPermissionedSwapperScript();
        script.setTesting(true);
        swapper = script.deploy();

        sdeusd = toolkit.getAddress("elixir.sdeusd");
        deusd = toolkit.getAddress("elixir.deusd");
        box = IBentoBoxLite(toolkit.getAddress("degenBox"));
        dummySwapper = address(new DummySwapper(address(box), deusd));
    }

    function testSwapper() public {
        pushPrank(SDEUSD_WHALE);
        sdeusd.safeTransfer(address(box), 100 ether);
        popPrank();

        box.deposit(sdeusd, address(box), address(swapper), 100 ether, 0);

        pushPrank(script.SDEUSD_CAULDRON_1());
        vm.expectRevert(OwnableOperators.Unauthorized.selector);
        swapper.swap(address(box), address(0), address(this), 0, 100 ether, "");
        popPrank();

        // authorize the cauldron
        pushPrank(swapper.owner());
        swapper.setOperator(script.SDEUSD_CAULDRON_1(), true);
        popPrank();

        pushPrank(script.SDEUSD_CAULDRON_1());
        vm.expectRevert(InvalidCooldown.selector);
        swapper.swap(address(0), address(0), dummySwapper, 0, 100 ether, "");
        popPrank();

        // authorize instant redeem
        pushPrank(SDEUSD_OWNER);
        IAccessControl(sdeusd).grantRole(COOLDOWN_UNRESTRICTED_STAKER_ROLE, address(swapper));
        popPrank();

        pushPrank(script.SDEUSD_CAULDRON_1());
        swapper.swap(address(0), address(0), alice, 0, 100 ether, abi.encode(address(dummySwapper), ""));
        assertEq(IERC20(deusd).balanceOf(alice), 100 ether);
        popPrank();
    }
}
