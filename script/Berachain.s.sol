// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "interfaces/IBentoBoxV1.sol";
import "BoringSolidity/ERC20.sol";
import "utils/BaseScript.sol";
import {ProxyOracle} from "oracles/ProxyOracle.sol";
import {FixedPriceOracle} from "oracles/FixedPriceOracle.sol";
import {ICauldronV4} from "interfaces/ICauldronV4.sol";
import {CauldronDeployLib} from "utils/CauldronDeployLib.sol";
import {IOracle} from "interfaces/IOracle.sol";
import {ILevSwapperV2} from "interfaces/ILevSwapperV2.sol";
import {ISwapperV2} from "interfaces/ISwapperV2.sol";

contract BerachainScript is BaseScript {
    function deploy() public returns (ISwapperV2 swapper, ILevSwapperV2 levSwapper) {
        vm.startBroadcast();
        // native wrapped token, called wETH for simplicity but could be wFTM on Fantom, wKAVA on KAVA etc.
        IERC20 weth = IERC20(toolkit.getAddress(block.chainid, "weth"));
        //address safe = toolkit.getAddress(block.chainid, "safe.ops");

        IBentoBoxV1 box = IBentoBoxV1(deploy("DegenBox", "DegenBox.sol:DegenBox", abi.encode(weth)));
        address mim = address(
            deploy("MIM", "MintableBurnableERC20.sol:MintableBurnableERC20", abi.encode(tx.origin, "Magic Internet Money", "MIM", 18))
        );

        ProxyOracle oracle = ProxyOracle(deploy("ProxyOracle", "ProxyOracle.sol:ProxyOracle", ""));

        FixedPriceOracle fixedPriceOracle = FixedPriceOracle(
            deploy("FixedPriceOracle", "FixedPriceOracle.sol:FixedPriceOracle", abi.encode("MIM/HONEY", 1e18, 18))
        );

        oracle.changeOracleImplementation(fixedPriceOracle);

        address masterContract = deploy("CauldronV4_MC", "CauldronV4.sol:CauldronV4", abi.encode(box, mim));
        ICauldronV4(masterContract).setFeeTo(tx.origin);

        ICauldronV4 cauldron = CauldronDeployLib.deployCauldronV4(
            "CauldronV4_MimHoneyBexLP",
            box,
            masterContract,
            IERC20(toolkit.getAddress(block.chainid, "bex.pool.mimhoney")),
            IOracle(address(oracle)),
            "",
            9000, // 90% ltv
            500, // 5% interests
            100, // 1% opening
            600 // 6% liquidation
        );

        levSwapper = ILevSwapperV2(
            deploy(
                "MimHoney_BexLpLevSwapper",
                "BexLpLevSwapper.sol:BexLpLevSwapper",
                abi.encode(
                    box,
                    toolkit.getAddress(block.chainid, "precompile.erc20dex"),
                    toolkit.getAddress(block.chainid, "bex.pool.mimhoney"),
                    toolkit.getAddress(block.chainid, "bex.token.mimhoney"),
                    mim,
                    address(0)
                )
            )
        );

        swapper = ISwapperV2(
            deploy(
                "MimHoney_BexLpSwapper",
                "BexLpSwapper.sol:BexLpSwapper",
                abi.encode(
                    box,
                    toolkit.getAddress(block.chainid, "precompile.erc20dex"),
                    toolkit.getAddress(block.chainid, "bex.pool.mimhoney"),
                    toolkit.getAddress(block.chainid, "bex.token.mimhoney"),
                    mim,
                    address(0)
                )
            )
        );

        vm.stopBroadcast();
    }
}
