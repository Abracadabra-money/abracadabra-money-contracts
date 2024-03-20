// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import "oracles/ProxyOracle.sol";
import "utils/CauldronDeployLib.sol";

struct TokenInfo {
    address cauldron;
    address token;
    string name;
    uint256 ltvBips;
    uint256 interestBips;
    uint256 borrowFeeBips;
    uint256 liquidationFeeBips;
}

contract MigrationCauldronsScript is BaseScript {

    
    TokenInfo[] public tokens;
    constructor() {
        tokens.push(TokenInfo(0x920D9BD936Da4eAFb5E25c6bDC9f6CB528953F9f, 0xa258C4606Ca8206D8aA700cE2143D7db854D168c, "yvWETH-v2", 8000, 0, 5, 750));
        tokens.push(TokenInfo(0xEBfDe87310dc22404d918058FAa4D56DC4E93f0A, 0x27b7b1ad7288079A66d12350c828D3C00A6F07d7, "yvcrvIB", 9000, 150, 5, 700));
        tokens.push(TokenInfo(0x551a7CfF4de931F32893c928bBc3D25bF1Fc5147, 0x7Da96a3891Add058AdA2E826306D812C638D87a7, "yvUSDT-v2", 9000, 80, 5, 300));
        tokens.push(TokenInfo(0x6cbAFEE1FaB76cA5B5e144c43B3B50d42b7C8c8f, 0x5f18C75AbDAe578b483E5F43f12a39cF75b973a9, "yvUSDC-v2", 9000, 80, 5, 300));
        tokens.push(TokenInfo(0x3410297D89dCDAf4072B805EFc1ef701Bb3dd9BF, 0x26FA3fFFB6EfE8c1E69103aCb4044C26B9A106a9, "sSPELL", 8000, 50, 5, 1000));
    }

    function deploy() public {
        if (block.chainid != ChainId.Mainnet) {
            revert("Unsupported chain");
        }

        address safe = toolkit.getAddress("mainnet.safe.ops");
        IBentoBoxV1 box = IBentoBoxV1(toolkit.getAddress("mainnet.degenBox"));

        vm.startBroadcast();

        for(uint i; i < tokens.length; i++) {
            TokenInfo memory token = tokens[i];
            // reusing existing Tricrypto oracle
            ProxyOracle oracle = ProxyOracle(deploy(string.concat("ProxyOracle", token.name), "ProxyOracle.sol:ProxyOracle", abi.encode()));
            IOracle oracleImpl = ICauldronV4(token.cauldron).oracle();
            bytes memory oracleData = ICauldronV4(token.cauldron).oracleData();
            oracle.changeOracleImplementation(oracleImpl);

            CauldronDeployLib.deployCauldronV4(
                string.concat("Mainnet_privileged_Cauldron", token.name),
                box,
                toolkit.getAddress("mainnet.privilegedCauldronV4"),
                IERC20(0xa258C4606Ca8206D8aA700cE2143D7db854D168c),
                oracle,
                oracleData,
                token.ltvBips,
                token.interestBips,
                token.borrowFeeBips,
                token.liquidationFeeBips
            );
            if (!testing()) {
                oracle.transferOwnership(safe);
            }
        }

        vm.stopBroadcast();
    }
}
