// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {BaseScript, ChainId} from "utils/BaseScript.sol";
import {ICauldronV2} from "interfaces/ICauldronV2.sol";
import {MasterContract, OracleUpdater} from "periphery/OracleUpdater.sol";

contract OracleUpdaterScript is BaseScript {
    function deploy() public returns (OracleUpdater oracleUpdater) {
        require(block.chainid == ChainId.Mainnet, "Wrong chain");

        ICauldronV2[] memory cauldrons = new ICauldronV2[](26);
        cauldrons[0] = ICauldronV2(0x05500e2Ee779329698DF35760bEdcAAC046e7C27);
        cauldrons[1] = ICauldronV2(0x003d5A75d284824Af736df51933be522DE9Eed0f);
        cauldrons[2] = ICauldronV2(0x98a84EfF6e008c5ed0289655CcdCa899bcb6B99F);
        cauldrons[3] = ICauldronV2(0xEBfDe87310dc22404d918058FAa4D56DC4E93f0A);
        cauldrons[4] = ICauldronV2(0x6cbAFEE1FaB76cA5B5e144c43B3B50d42b7C8c8f);
        cauldrons[5] = ICauldronV2(0x551a7CfF4de931F32893c928bBc3D25bF1Fc5147);
        cauldrons[6] = ICauldronV2(0x920D9BD936Da4eAFb5E25c6bDC9f6CB528953F9f);
        cauldrons[7] = ICauldronV2(0x4EAeD76C3A388f4a841E9c765560BBe7B3E4B3A0);
        cauldrons[8] = ICauldronV2(0x252dCf1B621Cc53bc22C256255d2bE5C8c32EaE4);
        cauldrons[9] = ICauldronV2(0x35a0Dd182E4bCa59d5931eae13D0A2332fA30321);
        cauldrons[10] = ICauldronV2(0xc1879bf24917ebE531FbAA20b0D05Da027B592ce);
        cauldrons[11] = ICauldronV2(0x9617b633EF905860D919b88E1d9d9a6191795341);
        cauldrons[12] = ICauldronV2(0xCfc571f3203756319c231d3Bc643Cee807E74636);
        cauldrons[13] = ICauldronV2(0x3410297D89dCDAf4072B805EFc1ef701Bb3dd9BF);
        cauldrons[14] = ICauldronV2(0x257101F20cB7243E2c7129773eD5dBBcef8B34E0);
        cauldrons[15] = ICauldronV2(0xbc36FdE44A7FD8f545d459452EF9539d7A14dd63);
        cauldrons[16] = ICauldronV2(0x59E9082E068Ddb27FC5eF1690F9a9f22B32e573f);
        cauldrons[17] = ICauldronV2(0x7b7473a76D6ae86CE19f7352A1E89F6C9dc39020);
        cauldrons[18] = ICauldronV2(0x390Db10e65b5ab920C19149C919D970ad9d18A41);
        cauldrons[19] = ICauldronV2(0x5ec47EE69BEde0b6C2A2fC0D9d094dF16C192498);
        cauldrons[20] = ICauldronV2(0xf179fe36a36B32a4644587B8cdee7A23af98ed37);
        cauldrons[21] = ICauldronV2(0xC319EEa1e792577C319723b5e60a15dA3857E7da);
        cauldrons[22] = ICauldronV2(0xFFbF4892822e0d552CFF317F65e1eE7b5D3d9aE6);
        cauldrons[23] = ICauldronV2(0x806e16ec797c69afa8590A55723CE4CC1b54050E);
        cauldrons[24] = ICauldronV2(0x6371EfE5CD6e3d2d7C477935b7669401143b7985);
        cauldrons[25] = ICauldronV2(0x0BCa8ebcB26502b013493Bf8fE53aA2B1ED401C1);

        MasterContract[] memory masterContractOverrides = new MasterContract[](2);
        masterContractOverrides[0] = MasterContract(ICauldronV2(0x469a991a6bB8cbBfEe42E7aB846eDEef1bc0B3d3), 90000, 103000);
        masterContractOverrides[1] = MasterContract(ICauldronV2(0x4a9Cb5D0B755275Fd188f87c0A8DF531B0C7c7D2), 75000, 112500);

        vm.startBroadcast();
        oracleUpdater = OracleUpdater(
            deploy("OracleUpdater", "OracleUpdater.sol:OracleUpdater", abi.encode(cauldrons, masterContractOverrides))
        );
        vm.stopBroadcast();
    }
}
