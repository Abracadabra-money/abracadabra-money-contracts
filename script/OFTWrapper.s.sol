// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import "mixins/OFTWrapper.sol";
import "oracles/WitnetOracle.sol";

contract OFTWrapperScript is BaseScript {
    using DeployerFunctions for Deployer;
    mapping (uint => uint) fixed_exchange_rate;

    constructor() {
       fixed_exchange_rate[1] = 539272521368673;
       fixed_exchange_rate[56] = 4188568516917942;
       fixed_exchange_rate[137] = 1378169790518191841;
       fixed_exchange_rate[250] = 4145116379323744988;
       fixed_exchange_rate[10] = 539272521368673;
       fixed_exchange_rate[42161] = 539272521368673;
       fixed_exchange_rate[43114] = 75282653144085340;
       fixed_exchange_rate[1285] = 207750420279100224;
       fixed_exchange_rate[2222] = 1174694726208026689;
    }

    function deploy() public returns (OFTWrapper wrapper){
        address oftV2 = toolkit.getAddress("oftv2", block.chainid);
        uint fix_rate = fixed_exchange_rate[block.chainid];
        address owner = toolkit.getAddress("safe.ops", block.chainid);
        if (block.chainid == ChainId.Kava) {
            address oracle = address(new WitnetOracle());
            wrapper = new OFTWrapper(fix_rate, oftV2, oracle, owner);
        } else {
            address oracle = toolkit.getAddress("oft.agg", block.chainid);
            wrapper = new OFTWrapper(fix_rate, oftV2, oracle, owner);
        }
    }
}