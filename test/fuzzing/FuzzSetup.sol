// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "fuzzlib/FuzzBase.sol";

import "./helper/FuzzStorageVariables.sol";

/**
 * @title FuzzSetup
 * @author 0xScourgedev
 * @notice Setup for the fuzzing suite
 */
contract FuzzSetup is FuzzBase, FuzzStorageVariables {
    function setup() internal {
        weth = new MockWETH("Wrapped ETH", "WETH");

        feeRateModelImpl = new FeeRateModelImpl();
        feeRateModel = new FeeRateModel(address(this), address(this));
        marketImpl = new MagicLP(address(this));
        factory = new Factory(address(marketImpl), IFeeRateModel(address(feeRateModel)), address(this));
        router = new Router(IWETH(address(weth)), IFactory(address(factory)));

        tokenA18 = new MockERC20("TokenA18", "TKA18", 18);
        tokenB18 = new MockERC20("TokenB18", "TKB18", 18);
        tokenA6 = new MockERC20("TokenA6", "TKA6", 6);
        tokenB6 = new MockERC20("TokenB6", "TKB6", 6);
        tokenA8 = new MockERC20("TokenA8", "TKA8", 8);
        tokenB8 = new MockERC20("TokenB8", "TKB8", 8);
        tokenA24 = new MockERC20("tokenA24", "TKA24", 24);
        tokenB24 = new MockERC20("tokenB24", "TKB24", 24);
    }

    function setupActors() internal {
        bool success;
        address[] memory targets = new address[](2);
        targets[0] = address(factory);
        targets[1] = address(router);

        tokens.push(tokenA18);
        tokens.push(tokenB18);
        tokens.push(tokenA6);
        tokens.push(tokenB6);
        tokens.push(tokenA8);
        tokens.push(tokenB8);
        tokens.push(tokenA24);
        tokens.push(tokenB24);

        (success, ) = address(weth).call{value: INITIAL_WETH_BALANCE * USERS.length}("");
        assert(success);

        for (uint8 i = 0; i < USERS.length; i++) {
            address user = USERS[i];
            (success, ) = address(user).call{value: INITIAL_BALANCE}("");
            assert(success);
            weth.transfer(user, INITIAL_WETH_BALANCE);

            for (uint8 j = 0; j < tokens.length; j++) {
                tokens[j].mint(user, INITIAL_TOKEN_BALANCE * (10 ** tokens[j].decimals()));
                for (uint8 k = 0; k < targets.length; k++) {
                    vm.prank(user);
                    tokens[j].approve(targets[k], type(uint128).max);
                    vm.prank(user);
                    weth.approve(targets[k], INITIAL_WETH_BALANCE);
                }
            }
        }

        tokens.push(weth);
    }
}
