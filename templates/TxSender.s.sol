// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "BoringSolidity/ERC20.sol";
import "OpenZeppelin/utils/Address.sol";
import "periphery/CauldronOwner.sol";
import "utils/BaseScript.sol";

contract TxSenderScript is BaseScript {
    function _mainnet() private {
        address target = constants.getAddress("mainnet.mimTreasury");
        bytes memory data = "";
        uint256 value = 0;

        _printStats(tx.origin, target, value, data);
        
        vm.startBroadcast();
        Address.functionCallWithValue(target, data, value);
        vm.stopBroadcast();
    }

    function _printStats(
        address from,
        address to,
        uint256 value,
        bytes memory data
    ) private {
        string memory tenderly = string.concat(
            string.concat(
                "https://dashboard.tenderly.co/abracadabra/magic-internet-money/simulator/new?blockIndex=0&from=",
                vm.toString(from)
            ),
            string.concat("&value=", vm.toString(value)),
            string.concat("&contractAddress=", vm.toString(to)),
            string.concat("&rawFunctionInput=", vm.toString(data)),
            string.concat("&network=", vm.toString(block.chainid))
        );
        console2.log("=== Transaction ===");
        console2.log("Target", to);
        console2.log("Value", value);
        console2.log("Data", vm.toString(data));
        console2.log("Tenderly", tenderly);
    }

    function run() public {
        if (block.chainid == ChainId.Mainnet) {
            _mainnet();
        } else {
            revert(string.concat("Unsupported Chain: ", vm.toString(block.chainid)));
        }
    }
}
