// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import "BoringSolidity/interfaces/IERC20.sol";
import "interfaces/IBentoBoxV1.sol";

contract TokenSwappersScript is BaseScript {
    using DeployerFunctions for Deployer;

    struct Config {
        uint256 chainId;
        string tokenName;
        address box;
        address token;
        address mim;
        address exchange;
    }

    Config[] public configs;

    function deploy() public {
        configs.push(
            Config({
                chainId: ChainId.Arbitrum,
                tokenName: "WETH",
                box: toolkit.getAddress(ChainId.Arbitrum, "sushiBentoBox"),
                token: toolkit.getAddress(ChainId.Arbitrum, "weth"),
                mim: toolkit.getAddress(ChainId.Arbitrum, "mim"),
                exchange: toolkit.getAddress(ChainId.Arbitrum, "aggregators.zeroXExchangeProxy")
            })
        );

        for (uint256 i = 0; i < configs.length; i++) {
            Config memory config = configs[i];
            if (config.chainId != block.chainid) {
                continue;
            }

            deployer.deploy_TokenSwapper(
                toolkit.prefixWithChainName(block.chainid, string.concat(config.tokenName, "_TokenSwapper")),
                IBentoBoxV1(config.box),
                IERC20(config.token),
                IERC20(config.mim),
                config.exchange
            );

            deployer.deploy_TokenLevSwapper(
                toolkit.prefixWithChainName(block.chainid, string.concat(config.tokenName, "_TokenLevSwapper")),
                IBentoBoxV1(config.box),
                IERC20(config.token),
                IERC20(config.mim),
                config.exchange
            );
        }
    }
}
