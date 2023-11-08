// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import "safe-contracts/GnosisSafe.sol";
import "safe-contracts/external/GnosisSafeMath.sol";

contract GnosisSafeMock is GnosisSafe {
    using GnosisSafeMath for uint256;

    function execTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation
    ) public payable virtual returns (bool success) {
        uint256 safeTxGas = 0;
        uint256 baseGas = 0;
        uint256 gasPrice = 0;
        address gasToken = address(0);
        address payable refundReceiver = payable(address(0));
        bytes32 txHash;

        {
            bytes memory txHashData = encodeTransactionData(
                to,
                value,
                data,
                operation,
                safeTxGas,
                baseGas,
                gasPrice,
                gasToken,
                refundReceiver,
                nonce
            );
            nonce++;
            txHash = keccak256(txHashData);
        }

        address guard = getGuard();
        require(gasleft() >= ((safeTxGas * 64) / 63).max(safeTxGas + 2500) + 500, "GS010");
        {
            uint256 gasUsed = gasleft();
            success = execute(to, value, data, operation, gasPrice == 0 ? (gasleft() - 2500) : safeTxGas);
            gasUsed = gasUsed.sub(gasleft());
            require(success || safeTxGas != 0 || gasPrice != 0, "GS013");

            if (success) emit ExecutionSuccess(txHash, 0);
            else emit ExecutionFailure(txHash, 0);
        }
        {
            if (guard != address(0)) {
                Guard(guard).checkAfterExecution(txHash, success);
            }
        }
    }
}
