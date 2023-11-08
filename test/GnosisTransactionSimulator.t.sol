// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import {Enum} from "safe-contracts/common/Enum.sol";
import {GnosisSafeMock} from "./mocks/GnosisSafeMock.sol";

contract GnosisTransactionSimulatorTest is BaseTest {
    function setUp() public override {
        super.setUp();
    }

    function test() public {}

    function _simulateDelegateCall(uint256 _chainId, uint256 _block, address _safeAddress, address _multicall, bytes memory _data) private {
        _simulate(_chainId, _block, _safeAddress, _multicall, Enum.Operation.DelegateCall, _data);
    }

    function _simulateCall(uint256 _chainId, uint256 _block, address _safeAddress, address _to, bytes memory _data) private {
        _simulate(_chainId, _block, _safeAddress, _to, Enum.Operation.Call, _data);
    }

    function _simulate(
        uint256 _chainId,
        uint256 _block,
        address _safeAddress,
        address _to,
        Enum.Operation operation,
        bytes memory _data
    ) private {
        fork(_chainId, _block);
        deployCodeTo("GnosisSafeMock.sol:GnosisSafeMock", "", _safeAddress);
        GnosisSafeMock(payable(_safeAddress)).execTransaction(_to, 0, _data, operation);
    }
}
