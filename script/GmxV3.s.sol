// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20} from "@BoringSolidity/interfaces/IERC20.sol";
import {Owned} from "@solmate/auth/Owned.sol";
import "utils/BaseScript.sol";
import {CauldronDeployLib} from "utils/CauldronDeployLib.sol";
import {IBentoBoxV1} from "/interfaces/IBentoBoxV1.sol";
import {ICauldronV4} from "/interfaces/ICauldronV4.sol";
import {IOracle} from "/interfaces/IOracle.sol";
import {IAggregator} from "/interfaces/IAggregator.sol";
import {IGmxV2ExchangeRouter, IGmxReader} from "/interfaces/IGmxV2.sol";
import {IGmCauldronOrderAgent} from "/periphery/GmxV2CauldronOrderAgent.sol";
import {ProxyOracle} from "/oracles/ProxyOracle.sol";
import {GmxV2CauldronV4} from "/cauldrons/GmxV2CauldronV4.sol";
import {GmxV2CauldronRouterOrder, GmxV2CauldronOrderAgent} from "/periphery/GmxV2CauldronOrderAgent.sol";
import {IOwnableOperators} from "/interfaces/IOwnableOperators.sol";

contract GmxV3Script is BaseScript {
    struct MarketDeployment {
        ProxyOracle oracle;
        ICauldronV4 cauldron;
    }

    IGmCauldronOrderAgent orderAgent;
    address masterContract;
    IBentoBoxV1 box;
    address safe;

    function deploy()
        public returns(bool status, address swapper1, address swapper2, address swapper3, address swapper4)
    {
        if (block.chainid != ChainId.Arbitrum) {
            revert("Wrong chain");
        }

        box = IBentoBoxV1(toolkit.getAddress(block.chainid, "degenBox"));
        IERC20 mim = IERC20(toolkit.getAddress(block.chainid, "mim"));

        vm.startBroadcast();
        swapper1 = deploy("WBTC_SingleSide_MIM_TokenSwapper", "TokenSwapper.sol:TokenSwapper", abi.encode(box, IERC20(toolkit.getAddress(block.chainid, "wbtc")), mim));
        swapper2 = deploy("WBTC_SingleSide_MIM_LevTokenSwapper", "TokenLevSwapper.sol:TokenLevSwapper", abi.encode(box, IERC20(toolkit.getAddress(block.chainid, "wbtc")), mim));
        swapper3 = deploy("WETH_SingleSide_MIM_TokenSwapper", "TokenSwapper.sol:TokenSwapper", abi.encode(box, IERC20(toolkit.getAddress(block.chainid, "weth")), mim));
        swapper4 = deploy("WETH_SingleSide_MIM_LevTokenSwapper", "TokenLevSwapper.sol:TokenLevSwapper", abi.encode(box, IERC20(toolkit.getAddress(block.chainid, "weth")), mim));
        vm.stopBroadcast();

        status = true;

    }

}