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
import {ChainlinkOracle} from "/oracles/ChainlinkOracle.sol";
import {GmxV2CauldronV4} from "/cauldrons/GmxV2CauldronV4.sol";
import {GmxV2CauldronRouterOrder, GmxV2CauldronOrderAgent} from "/periphery/GmxV2CauldronOrderAgent.sol";
import {IOwnableOperators} from "/interfaces/IOwnableOperators.sol";

contract GmxV2OrderAgentScript is BaseScript {

    IGmCauldronOrderAgent orderAgent;
    address masterContract;
    IBentoBoxV1 box;
    address safe;

    function deploy()
        public
        returns (
            address _masterContract,
            IGmCauldronOrderAgent _orderAgent
        )
    {

        if (block.chainid != ChainId.Arbitrum) {
            revert("Wrong chain");
        }

        box = IBentoBoxV1(toolkit.getAddress(block.chainid, "degenBox"));
        safe = toolkit.getAddress(block.chainid, "safe.ops");
        //IERC20 mim = IERC20(toolkit.getAddress(block.chainid, "mim"));
        address usdc = toolkit.getAddress(block.chainid, "usdc");
        address weth = toolkit.getAddress(block.chainid, "weth");
        IGmxV2ExchangeRouter router = IGmxV2ExchangeRouter(toolkit.getAddress(block.chainid, "gmx.v2.exchangeRouter"));
        address syntheticsRouter = toolkit.getAddress(block.chainid, "gmx.v2.syntheticsRouter");
        IGmxReader reader = IGmxReader(toolkit.getAddress(block.chainid, "gmx.v2.reader"));

        vm.startBroadcast();
        //deploy("USDC_MIM_TokenSwapper", "TokenSwapper.sol:TokenSwapper", abi.encode(box, IERC20(usdc), mim));
        //deploy("USDC_MIM_LevTokenSwapper", "TokenLevSwapper.sol:TokenLevSwapper", abi.encode(box, IERC20(usdc), mim));

        GmxV2CauldronRouterOrder routerOrderImpl = GmxV2CauldronRouterOrder(
            payable(
                deploy(
                    "GmxV2CauldronRouterOrderImpl",
                    "GmxV2CauldronOrderAgent.sol:GmxV2CauldronRouterOrder",
                    abi.encode(box, router, syntheticsRouter, reader, weth, safe)
                )
            )
        );

        orderAgent = _orderAgent = IGmCauldronOrderAgent(
            deploy(
                "GmxV2CauldronOrderAgent",
                "GmxV2CauldronOrderAgent.sol:GmxV2CauldronOrderAgent",
                abi.encode(box, address(routerOrderImpl), tx.origin)
            )
        );

        // non inverted USDC/USD feed to be used for GmxV2CauldronRouterOrder `orderValueInCollateral`
        ChainlinkOracle usdcOracle = ChainlinkOracle(0xeCbD548b677c1a8FfBACaCF8Bc8c38DF938BDbeC);

        if (orderAgent.oracles(usdc) != IOracle(address(usdcOracle))) {
            orderAgent.setOracle(usdc, usdcOracle);
        }

        // Deploy GMX Cauldron MasterContract
        masterContract = _masterContract = 0x1B867b05004c26415aee34b20B1e51bA77A67043; /*deploy(
            "GmxV2CauldronV4_MC",
            "GmxV2CauldronV4.sol:GmxV2CauldronV4",
            abi.encode(box, mim, tx.origin)
        );*/



        address[5] memory cauldrons = [0x2b02bBeAb8eCAb792d3F4DDA7a76f63Aa21934FA, 0xD7659D913430945600dfe875434B6d80646d552A, 0x4F9737E994da9811B8830775Fd73E2F1C8e40741, 0x7962ACFcfc2ccEBC810045391D60040F635404fb, 0x66805F6e719d7e67D46e8b2501C1237980996C6a];

        for (uint i; i < cauldrons.length; i++) {
            if (!IOwnableOperators(address(orderAgent)).operators(cauldrons[i])) {
                IOwnableOperators(address(orderAgent)).setOperator(cauldrons[i], true);
            }
            if (orderAgent.oracles(address(ICauldronV4(cauldrons[i]).collateral())) != ICauldronV4(cauldrons[i]).oracle()) {
                orderAgent.setOracle(address(ICauldronV4(cauldrons[i]).collateral()), ICauldronV4(cauldrons[i]).oracle());
            }
        }

        if (!testing()) {
            if (Owned(address(masterContract)).owner() == tx.origin) {
                Owned(address(masterContract)).transferOwnership(safe);
            }

            if (Owned(address(orderAgent)).owner() == tx.origin) {
                Owned(address(orderAgent)).transferOwnership(safe);
            }
        }

        vm.stopBroadcast();
    }

}
