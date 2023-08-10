// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import "mixins/OFTWrapper.sol";
import "oracles/aggregators/WitnetAggregator.sol";

contract OFTWrapperScript is BaseScript {
    using DeployerFunctions for Deployer;
    mapping(uint => uint) fixed_exchange_rate;

    // CREATE3 salts
    bytes32 constant OFT_WRAPPER_SALT = keccak256(bytes("OFTWrapper-v2"));

    constructor() {
        fixed_exchange_rate[1] = 539272521368673;
        fixed_exchange_rate[56] = 4188568516917942;
        fixed_exchange_rate[137] = 1550000000000000000;
        fixed_exchange_rate[250] = 4145116379323744988;
        fixed_exchange_rate[10] = 539272521368673;
        fixed_exchange_rate[42161] = 539272521368673;
        fixed_exchange_rate[43114] = 75282653144085340;
        fixed_exchange_rate[1285] = 207750420279100224;
        fixed_exchange_rate[2222] = 1174694726208026689;
    }

    function deploy() public returns (OFTWrapper wrapper) {
        deployer.setAutoBroadcast(false);
        address oftV2 = toolkit.getAddress("oftv2", block.chainid);
        uint fix_rate = fixed_exchange_rate[block.chainid];
        address owner = toolkit.getAddress("safe.ops", block.chainid);
        string memory chainName = toolkit.getChainName(block.chainid);

        vm.startBroadcast();
        if (block.chainid == ChainId.Kava) {
            address router = 0xD39D4d972C7E166856c4eb29E54D3548B4597F53;
            bytes4 id = bytes4(0xde77dd55);
            uint8 decimals = 6;
            address oracle = address(new WitnetAggregator(id, router, decimals));

            wrapper = OFTWrapper(
                deployUsingCreate3(
                    string.concat(chainName, "_OFTWrapper"),
                    OFT_WRAPPER_SALT,
                    "OFTWrapper.sol:OFTWrapper",
                    abi.encode(fix_rate, oftV2, oracle, owner),
                    0
                )
            );
        } else {
            address oracle = toolkit.getAddress("oft.agg", block.chainid);
            wrapper = OFTWrapper(
                deployUsingCreate3(
                    string.concat(chainName, "_OFTWrapper"),
                    OFT_WRAPPER_SALT,
                    "OFTWrapper.sol:OFTWrapper",
                    abi.encode(fix_rate, oftV2, oracle, owner),
                    0
                )
            );
        }

        vm.stopBroadcast();
    }
}
