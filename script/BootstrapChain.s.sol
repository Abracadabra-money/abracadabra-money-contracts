// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "@BoringSolidity/ERC20.sol";
import "utils/BaseScript.sol";
import "/interfaces/IBentoBoxV1.sol";
import {CauldronRegistryScript} from "script/CauldronRegistry.s.sol";
import {CauldronOwnerScript} from "script/CauldronOwner.s.sol";
import {CauldronV4Script} from "script/CauldronV4.s.sol";

contract BootstrapChainScript is BaseScript {
    address safe;

    function deploy() public {
        safe = toolkit.getAddress(block.chainid, "safe.ops");

        //deployDegenBox();
        //deployMIM();
        //deployCauldronRegistry();
        //deployCauldronOwner();
        //deployCauldronV4();
        deployMarketLens();
    }

    function deployDegenBox() public {
        vm.startBroadcast();
        IERC20 weth = IERC20(toolkit.getAddress(block.chainid, "weth"));

        IBentoBoxV1 degenBox = IBentoBoxV1(deploy("DegenBox", "DegenBox.sol:DegenBox", abi.encode(weth)));

        if (!testing()) {
            if (degenBox.owner() == tx.origin) {
                degenBox.transferOwnership(safe, true, false);
            }
        }
        vm.stopBroadcast();
    }

    function deployMIM() public {
        vm.startBroadcast();
        deploy("MIM", "MintableBurnableERC20.sol:MintableBurnableERC20", abi.encode(tx.origin, "Magic Internet Money", "MIM", 18));
        vm.stopBroadcast();
    }

    function deployCauldronRegistry() public {
        CauldronRegistryScript script = new CauldronRegistryScript();
        script.deploy();
    }

    function deployCauldronOwner() public {
        CauldronOwnerScript script = new CauldronOwnerScript();
        script.deploy();
    }

    function deployCauldronV4() public {
        CauldronV4Script script = new CauldronV4Script();
        script.deploy();
    }

    function deployMarketLens() public {
        vm.startBroadcast();
        deploy("MarketLens", "MarketLens.sol:MarketLens", abi.encode(tx.origin));
        vm.stopBroadcast();
    }
}
