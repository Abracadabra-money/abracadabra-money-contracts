// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import "interfaces/IMintableBurnable.sol";
import "mixins/Operatable.sol";

contract MIMLayerZeroScript is BaseScript {
    using DeployerFunctions for Deployer;

    enum Stage {
        Testing,
        Production
    }

    function deploy() public {
        _deploy(Stage.Testing);
        //_deploy(Stage.Production);
    }

    function _deploy(Stage _stage) internal {
        uint8 sharedDecimals = 8;
        address mim = constants.getAddress("mim", block.chainid);
        address lzEndpoint = constants.getAddress("LZendpoint", block.chainid);
        string memory chainName = constants.getChainName(block.chainid);

        if (block.chainid == ChainId.Mainnet) {
            if (_stage == Stage.Production) {
                deployer.deploy_ProxyOFTV2("Mainnet_ProxyOFTV2", mim, sharedDecimals, lzEndpoint);
            } else {
                deployer.deploy_ProxyOFTV2("Mainnet_ProxyOFTV2_Mock", mim, sharedDecimals, lzEndpoint);
            }
        } else {
            address token;
            address minterBurner;

            if (_stage == Stage.Production) {
                minterBurner = address(
                    deployer.deploy_ElevatedMinterBurner(string.concat(chainName, "_ElevatedMinterBurner"), IMintableBurnable(mim))
                );
                token = address(
                    deployer.deploy_IndirectOFTV2(
                        string.concat(chainName, "_IndirectOFTV2"),
                        mim,
                        IMintableBurnable(minterBurner),
                        sharedDecimals,
                        lzEndpoint
                    )
                );
            } else {
                mim = address(
                    deployer.deploy_AnyswapV5ERC20Mock(
                        string.concat(chainName, "_AnyswapMIM_Mock"),
                        "Magic Internet Money",
                        "MIM",
                        18,
                        address(0),
                        tx.origin
                    )
                );
                minterBurner = address(
                    deployer.deploy_ElevatedMinterBurner(string.concat(chainName, "_ElevatedMinterBurner_Mock"), IMintableBurnable(mim))
                );

                startBroadcast();
                AnyswapV5ERC20Mock(mim).setMinter(minterBurner);
                AnyswapV5ERC20Mock(mim).applyMinter();
                AnyswapV5ERC20Mock(mim).setVault(tx.origin);
                AnyswapV5ERC20Mock(mim).applyVault();
                stopBroadcast();

                token = address(
                    deployer.deploy_IndirectOFTV2(
                        string.concat(chainName, "_IndirectOFTV2_Mock"),
                        mim,
                        IMintableBurnable(minterBurner),
                        sharedDecimals,
                        lzEndpoint
                    )
                );
            }

            /// @notice The layerzero token needs to be able to mint/burn anyswap tokens
            startBroadcast();
            Operatable(minterBurner).setOperator(token, true);
            Operatable(minterBurner).setOperator(address(this), false);
            Operatable(minterBurner).transferOwnership(tx.origin, true, false);
            stopBroadcast();
        }
    }
}
