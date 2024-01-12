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

        // forge verify-contract contract_address DegenBox --etherscan-api-key=xxxx --watch --constructor-args $(cast abi-encode "constructor(address)" 0x5806E416dA447b267cEA759358cF22Cc41FAE80F)  --retries=2 --verifier-url=https://api.routescan.io/v2/network/testnet/evm/80085/etherscan/api/ 
        IBentoBoxV1 box = IBentoBoxV1(deploy("DegenBox", "DegenBox.sol:DegenBox", abi.encode(weth)));

        // forge verify-contract contract_address MintableBurnableERC20 --etherscan-api-key=xxxx --watch --constructor-args $(cast abi-encode "constructor(address,string,string,uint8)" 0xfB3485c2e209A5cfBDC1447674256578f1A80eE3 "Magic Internet Money" "MIM" 18)  --retries=2 --verifier-url=https://api.routescan.io/v2/network/testnet/evm/80085/etherscan/api/ 
        address mim = address(
            deploy("MIM", "MintableBurnableERC20.sol:MintableBurnableERC20", abi.encode(tx.origin, "Magic Internet Money", "MIM", 18))
        );

        // forge verify-contract contract_address ProxyOracle --etherscan-api-key=xxxx --watch --retries=2 --verifier-url=https://api.routescan.io/v2/network/testnet/evm/80085/etherscan/api/ 
        ProxyOracle oracle = ProxyOracle(deploy("ProxyOracle", "ProxyOracle.sol:ProxyOracle", ""));

        // forge verify-contract contract_address FixedPriceOracle --etherscan-api-key=xxxx --watch --constructor-args $(cast abi-encode "constructor(string,uint256,uint8)" "MIM/HONEY" 1000000000000000000 18)  --retries=2 --verifier-url=https://api.routescan.io/v2/network/testnet/evm/80085/etherscan/api/ 
        FixedPriceOracle fixedPriceOracle = FixedPriceOracle(
            deploy("MimHoney_Oracle_Impl", "FixedPriceOracle.sol:FixedPriceOracle", abi.encode("MIM/HONEY", 1e18, 18))
        );

        oracle.changeOracleImplementation(fixedPriceOracle);

        // forge verify-contract 0x0B938cC6A48e1C3b48A33adcF9a726e776d348dd CauldronV4 --etherscan-api-key=xxxx --watch --constructor-args $(cast abi-encode "constructor(address,address)" 0x7a3b799E929C9bef403976405D8908fa92080449 0xB734c264F83E39Ef6EC200F99550779998cC812d)  --retries=2 --verifier-url=https://api.routescan.io/v2/network/testnet/evm/80085/etherscan/api/
        address masterContract = deploy(
            "CauldronV4_MC",
            "CauldronV4.sol:CauldronV4",
            abi.encode(toolkit.getAddress(block.chainid, "degenBox"), toolkit.getAddress(block.chainid, "mim"))
        );
        ICauldronV4(masterContract).setFeeTo(tx.origin);

        ICauldronV4 cauldron = CauldronDeployLib.deployCauldronV4(
            "CauldronV4_MimHoneyBexLP",
            IBentoBoxV1(toolkit.getAddress(block.chainid, "degenBox")),
            toolkit.getAddress(block.chainid, "cauldronV4"),
            IERC20(toolkit.getAddress(block.chainid, "bex.token.mimhoney")),
            IOracle(address(0x279D54aDD72935d845074675De0dbcfdc66800a3)),
            "",
            9000, // 90% ltv
            500, // 5% interests
            100, // 1% opening
            600 // 6% liquidation
        );

        // FOUNDRY_PROFILE=shanghai forge verify-contract 0xD6b8bd85A9593cb47c8C15C95bbF3e593c5Dc591 BexLpLevSwapper --etherscan-api-key=xxxx --watch --constructor-args $(cast abi-encode "constructor(address,address,address,address,address,address)" 0x7a3b799E929C9bef403976405D8908fa92080449 0x0D5862FDBDD12490F9B4DE54C236CFF63B038074 0xC793C76fE0D5c79550034983D966c21a50Fb5e38 0x2dd5691de6528854c60fd67da57ad185f6d1666d 0xB734c264F83E39Ef6EC200F99550779998cC812d 0x0000000000000000000000000000000000000000) --retries=2 --verifier-url=https://api.routescan.io/v2/network/testnet/evm/80085/etherscan/api/
        levSwapper = ILevSwapperV2(
            deploy(
                "MimHoney_BexLpLevSwapper",
                "BexLpLevSwapper.sol:BexLpLevSwapper",
                abi.encode(
                    toolkit.getAddress(block.chainid, "degenBox"),
                    toolkit.getAddress(block.chainid, "precompile.erc20dex"),
                    toolkit.getAddress(block.chainid, "bex.pool.mimhoney"),
                    toolkit.getAddress(block.chainid, "bex.token.mimhoney"),
                    toolkit.getAddress(block.chainid, "mim"),
                    address(0)
                )
            )
        );

        // FOUNDRY_PROFILE=shanghai forge verify-contract 0x6C0fB20908Bb1AE089Af7b2dE774968Add8fD5b7 BexLpSwapper --etherscan-api-key=xxxx --watch --constructor-args $(cast abi-encode "constructor(address,address,address,address,address,address)" 0x7a3b799E929C9bef403976405D8908fa92080449 0x0D5862FDBDD12490F9B4DE54C236CFF63B038074 0xC793C76fE0D5c79550034983D966c21a50Fb5e38 0x2dd5691de6528854c60fd67da57ad185f6d1666d 0xB734c264F83E39Ef6EC200F99550779998cC812d 0x0000000000000000000000000000000000000000) --retries=2 --verifier-url=https://api.routescan.io/v2/network/testnet/evm/80085/etherscan/api/
        swapper = ISwapperV2(
            deploy(
                "MimHoney_BexLpSwapper",
                "BexLpSwapper.sol:BexLpSwapper",
                abi.encode(
                    toolkit.getAddress(block.chainid, "degenBox"),
                    toolkit.getAddress(block.chainid, "precompile.erc20dex"),
                    toolkit.getAddress(block.chainid, "bex.pool.mimhoney"),
                    toolkit.getAddress(block.chainid, "bex.token.mimhoney"),
                    toolkit.getAddress(block.chainid, "mim"),
                    address(0)
                )
            )
        );

        vm.stopBroadcast();
    }
}
