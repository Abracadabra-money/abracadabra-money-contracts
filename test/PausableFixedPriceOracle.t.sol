// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8;

import {Test} from "forge-std/Test.sol";
import {SymTest} from "halmos-cheatcodes/SymTest.sol";
import {PausableFixedPriceOracle} from "/oracles/PausableFixedPriceOracle.sol";
import {FixedPriceOracle} from "/oracles/FixedPriceOracle.sol";

contract PausableFixedPriceOracleSymTest is Test, SymTest {
    PausableFixedPriceOracle oracle;
    address owner;
    string desc;
    uint256 price;
    uint8 decimals;
    bool paused;

    function setUp() public {
        desc = "Test Oracle";
        price = svm.createUint256("price");
        decimals = uint8(svm.createUint(8, "decimals"));
        paused = svm.createBool("paused");

        owner = svm.createAddress("owner");

        vm.assume(owner != address(0));

        vm.prank(owner);
        oracle = new PausableFixedPriceOracle(desc, price, decimals, paused);
    }

    /// @dev Proves that the oracle returns the correct price when not paused
    function proveGetReturnsCorrectPriceWhenNotPaused(bytes calldata data) public view {
        vm.assume(!oracle.paused());

        (bool success, uint256 returnedPrice) = oracle.get(data);

        assertTrue(success);
        assertEq(returnedPrice, oracle.price());
    }

    /// @dev Proves that the oracle returns the correct price when peeking and not paused
    function provePeekReturnsCorrectPriceWhenNotPaused(bytes calldata data) public view {
        vm.assume(!oracle.paused());

        (bool success, uint256 returnedPrice) = oracle.peek(data);

        assertTrue(success);
        assertEq(returnedPrice, oracle.price());
    }

    /// @dev Proves that peekSpot returns the correct price when not paused
    function provePeekSpotReturnsCorrectPriceWhenNotPaused(bytes calldata data) public view {
        vm.assume(!oracle.paused());

        uint256 returnedPrice = oracle.peekSpot(data);

        assertEq(returnedPrice, oracle.price());
    }

    /// @dev Proves that get always reverts with ErrPaused when paused
    function proveGetAlwaysRevertsWhenPaused(bytes calldata data) public {
        vm.assume(oracle.paused());

        (bool success, bytes memory returnData) = address(oracle).call(
            abi.encodeWithSelector(oracle.get.selector, data)
        );

        assertFalse(success);
        // Check that it reverts with ErrPaused()
        assertEq(returnData, abi.encodeWithSelector(PausableFixedPriceOracle.ErrPaused.selector));
    }

    /// @dev Proves that peek always reverts with ErrPaused when paused
    function provePeekAlwaysRevertsWhenPaused(bytes calldata data) public {
        vm.assume(oracle.paused());

        (bool success, bytes memory returnData) = address(oracle).call(
            abi.encodeWithSelector(oracle.peek.selector, data)
        );

        assertFalse(success);
        // Check that it reverts with ErrPaused()
        assertEq(returnData, abi.encodeWithSelector(PausableFixedPriceOracle.ErrPaused.selector));
    }

    /// @dev Proves that peekSpot always reverts with ErrPaused when paused
    function provePeekSpotAlwaysRevertsWhenPaused(bytes calldata data) public {
        vm.assume(oracle.paused());

        (bool success, bytes memory returnData) = address(oracle).call(
            abi.encodeWithSelector(oracle.peekSpot.selector, data)
        );

        assertFalse(success);
        // Check that it reverts with ErrPaused()
        assertEq(returnData, abi.encodeWithSelector(PausableFixedPriceOracle.ErrPaused.selector));
    }

    /// @dev Proves that any non owner cannot pause/unpause the oracle
    function proveNonOwnerCanPause(address caller, bool newPausedState) public {
        vm.assume(caller != owner);

        vm.prank(caller);
        (bool success, bytes memory returnData) = address(oracle).call(
            abi.encodeWithSelector(oracle.pause.selector, newPausedState)
        );

        assertFalse(success);
        // Check that it reverts with "UNAUTHORIZED"
        assertEq(returnData, abi.encodeWithSignature("Error(string)", "UNAUTHORIZED"));
    }

    /// @dev Proves that the owner can successfully pause/unpause the oracle
    function proveOwnerCanPause(bool newPausedState) public {
        vm.prank(owner);
        oracle.pause(newPausedState);

        assertEq(oracle.paused(), newPausedState);
    }

    /// @dev Proves that any non owner cannot set the price
    function proveNonOwnerCannotSetPrice(address caller, uint256 newPrice) public {
        vm.assume(caller != owner);

        vm.prank(caller);
        (bool success, bytes memory returnData) = address(oracle).call(
            abi.encodeWithSelector(oracle.setPrice.selector, newPrice)
        );

        assertFalse(success);
        // Check that it reverts with "UNAUTHORIZED"
        assertEq(returnData, abi.encodeWithSignature("Error(string)", "UNAUTHORIZED"));
    }

    /// @dev Proves that the owner can successfully set the price
    function proveOwnerCanSetPrice(uint256 newPrice) public {
        vm.prank(owner);
        oracle.setPrice(newPrice);

        assertEq(oracle.price(), newPrice);
    }

    /// @dev Proves that decimals are immutable and correct
    function proveDecimalsAreImmutable() public {
        uint8 expectedDecimals = oracle.decimals();

        // Try to change state in various ways
        vm.prank(owner);
        oracle.setPrice(12345);

        vm.prank(owner);
        oracle.pause(!oracle.paused());

        // Decimals should remain unchanged
        assertEq(oracle.decimals(), expectedDecimals);
    }

    /// @dev Proves that name and symbol return the correct description
    function proveNameAndSymbolReturnDescription(bytes calldata data) public view {
        string memory expectedDesc = oracle.desc();

        assertEq(oracle.name(data), expectedDesc);
        assertEq(oracle.symbol(data), expectedDesc);
    }

    /// @dev Proves that the oracle state is consistent after multiple operations
    function proveStateConsistencyAfterOperations(uint256 newPrice, bool newPausedState) public {
        vm.startPrank(owner);

        // Set new price
        oracle.setPrice(newPrice);
        assertEq(oracle.price(), newPrice);

        // Change pause state
        oracle.pause(newPausedState);
        assertEq(oracle.paused(), newPausedState);

        // Verify price hasn't changed
        assertEq(oracle.price(), newPrice);

        // Verify decimals and description haven't changed
        assertEq(oracle.decimals(), decimals);
        assertEq(oracle.desc(), desc);

        vm.stopPrank();
    }

    /// @dev Proves that get/peek behavior is consistent with pause state
    function proveGetPeekConsistentWithPauseState(bytes calldata data) public {
        bool isPaused = oracle.paused();

        if (isPaused) {
            (bool success1, bytes memory returnData1) = address(oracle).call(
                abi.encodeWithSelector(oracle.get.selector, data)
            );
            assertFalse(success1);

            (bool success2, bytes memory returnData2) = address(oracle).call(
                abi.encodeWithSelector(oracle.peek.selector, data)
            );
            assertFalse(success2);

            (bool success3, bytes memory retrunData3) = address(oracle).call(
                abi.encodeWithSelector(oracle.peekSpot.selector, data)
            );
            assertFalse(success3);

            assertEq(returnData1, returnData2);
            assertEq(returnData2, retrunData3);
            assertEq(retrunData3, abi.encodePacked(PausableFixedPriceOracle.ErrPaused.selector));
        } else {
            (bool success1, uint256 price1) = oracle.get(data);
            (bool success2, uint256 price2) = oracle.peek(data);
            uint256 price3 = oracle.peekSpot(data);

            assertTrue(success1);
            assertTrue(success2);
            assertEq(price1, price2);
            assertEq(price2, price3);
            assertEq(price1, oracle.price());
        }
    }

    /// @dev Proves that oracle functions never revert when not paused
    function proveNeverRevertWhenNotPaused(bytes calldata data) public {
        vm.assume(!oracle.paused());

        // These should never revert when not paused
        (bool success1, ) = address(oracle).call(
            abi.encodeWithSelector(oracle.get.selector, data)
        );
        assertTrue(success1);

        (bool success2, ) = address(oracle).call(
            abi.encodeWithSelector(oracle.peek.selector, data)
        );
        assertTrue(success2);

        (bool success3, ) = address(oracle).call(
            abi.encodeWithSelector(oracle.peekSpot.selector, data)
        );
        assertTrue(success3);

        // These view functions should always succeed
        oracle.name(data);
        oracle.symbol(data);
        oracle.decimals();
        oracle.price();
        oracle.desc();
        oracle.paused();
    }

    /// @dev Proves that price setting maintains all other state
    function provePriceSettingMaintainsOtherState(uint256 newPrice) public {
        bool originalPaused = oracle.paused();
        uint8 originalDecimals = oracle.decimals();
        string memory originalDesc = oracle.desc();
        address originalOwner = oracle.owner();

        vm.prank(owner);
        oracle.setPrice(newPrice);

        assertEq(oracle.price(), newPrice);
        assertEq(oracle.paused(), originalPaused);
        assertEq(oracle.decimals(), originalDecimals);
        assertEq(oracle.desc(), originalDesc);
        assertEq(oracle.owner(), originalOwner);
    }

    /// @dev Proves that pause state changes maintain all other state
    function provePauseStateMaintainsOtherState(bool newPausedState) public {
        uint256 originalPrice = oracle.price();
        uint8 originalDecimals = oracle.decimals();
        string memory originalDesc = oracle.desc();
        address originalOwner = oracle.owner();

        vm.prank(owner);
        oracle.pause(newPausedState);

        assertEq(oracle.paused(), newPausedState);
        assertEq(oracle.price(), originalPrice);
        assertEq(oracle.decimals(), originalDecimals);
        assertEq(oracle.desc(), originalDesc);
        assertEq(oracle.owner(), originalOwner);
    }
}
