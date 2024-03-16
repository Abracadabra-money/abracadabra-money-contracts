// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "../../properties/Properties.sol";
import "./PostconditionsBase.sol";

/**
 * @title PostconditionsRouter
 * @author 0xScourgedev
 * @notice Contains all postconditions for Router
 */
abstract contract PostconditionsRouter is PostconditionsBase {
    function addLiquidityPostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address[] memory poolsToUpdate,
        uint256 previewShares
    ) internal {
        if (success) {
            (, , uint256 actualShares) = abi.decode(returnData, (uint256, uint256, uint256));
            _after(actorsToUpdate, poolsToUpdate);
            invariant_LIQ_01(poolsToUpdate[0]);
            invariant_LIQ_02(poolsToUpdate[0], false);
            invariant_LIQ_03(poolsToUpdate[0]);
            invariant_LIQ_04(poolsToUpdate[0]);
            invariant_LIQ_12(previewShares, actualShares);
            onSuccessInvariantsGeneral(poolsToUpdate);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function addLiquidityETHPostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address[] memory poolsToUpdate,
        uint256 previewShares
    ) internal {
        if (success) {
            (, , uint256 actualShares) = abi.decode(returnData, (uint256, uint256, uint256));
            _after(actorsToUpdate, poolsToUpdate);
            invariant_LIQ_01(poolsToUpdate[0]);
            invariant_LIQ_02(poolsToUpdate[0], true);
            invariant_LIQ_03(poolsToUpdate[0]);
            invariant_LIQ_04(poolsToUpdate[0]);
            invariant_LIQ_12(previewShares, actualShares);
            onSuccessInvariantsGeneral(poolsToUpdate);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function addLiquidityETHUnsafePostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address[] memory poolsToUpdate,
        uint256 previewShares
    ) internal {
        if (success) {
            uint256 actualShares = abi.decode(returnData, (uint256));
            _after(actorsToUpdate, poolsToUpdate);
            invariant_LIQ_01(poolsToUpdate[0]);
            invariant_LIQ_02(poolsToUpdate[0], true);
            invariant_LIQ_03(poolsToUpdate[0]);
            invariant_LIQ_04(poolsToUpdate[0]);
            invariant_LIQ_13(previewShares, actualShares);
            onSuccessInvariantsGeneral(poolsToUpdate);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function addLiquidityUnsafePostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address[] memory poolsToUpdate,
        uint256 previewShares
    ) internal {
        if (success) {
            uint256 actualShares = abi.decode(returnData, (uint256));
            _after(actorsToUpdate, poolsToUpdate);
            invariant_LIQ_01(poolsToUpdate[0]);
            invariant_LIQ_02(poolsToUpdate[0], false);
            invariant_LIQ_03(poolsToUpdate[0]);
            invariant_LIQ_04(poolsToUpdate[0]);
            invariant_LIQ_13(previewShares, actualShares);
            onSuccessInvariantsGeneral(poolsToUpdate);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function createPoolPostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address[] memory poolsToUpdate,
        address baseToken,
        address quoteToken
    ) internal {
        if (success) {
            (address pool, ) = abi.decode(returnData, (address, uint256));
            allPools.push(pool);
            pools[baseToken][quoteToken] = pool;
            pools[quoteToken][baseToken] = pool;
            availablePools[quoteToken].push(pool);
            availablePools[baseToken].push(pool);
            poolsToUpdate[0] = pool;

            _after(actorsToUpdate, poolsToUpdate);
            onSuccessInvariantsGeneral(poolsToUpdate);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function createPoolETHPostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address[] memory poolsToUpdate,
        address baseToken
    ) internal {
        if (success) {
            (address pool, ) = abi.decode(returnData, (address, uint256));
            allPools.push(pool);
            pools[baseToken][address(weth)] = pool;
            pools[address(weth)][baseToken] = pool;
            availablePools[address(weth)].push(baseToken);
            availablePools[baseToken].push(address(weth));
            poolsToUpdate[0] = pool;

            _after(actorsToUpdate, poolsToUpdate);
            onSuccessInvariantsGeneral(poolsToUpdate);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function removeLiquidityPostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address[] memory poolsToUpdate,
        uint256 sharesIn,
        uint256 previewBase,
        uint256 previewQuote
    ) internal {
        if (success) {
            (uint256 actualBase, uint256 actualQuote) = abi.decode(returnData, (uint256, uint256));
            _after(actorsToUpdate, poolsToUpdate);
            invariant_LIQ_05(poolsToUpdate[0]);
            invariant_LIQ_06(poolsToUpdate[0], false);
            invariant_LIQ_07(poolsToUpdate[0], sharesIn);
            invariant_LIQ_08(poolsToUpdate[0], sharesIn);
            invariant_LIQ_09(poolsToUpdate[0], sharesIn);
            invariant_LIQ_14(previewBase, previewQuote, actualBase, actualQuote);
            onSuccessInvariantsGeneral(poolsToUpdate);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function removeLiquidityETHPostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address[] memory poolsToUpdate,
        uint256 sharesIn
    ) internal {
        if (success) {
            _after(actorsToUpdate, poolsToUpdate);
            invariant_LIQ_05(poolsToUpdate[0]);
            invariant_LIQ_06(poolsToUpdate[0], true);
            invariant_LIQ_07(poolsToUpdate[0], sharesIn);
            invariant_LIQ_08(poolsToUpdate[0], sharesIn);
            invariant_LIQ_09(poolsToUpdate[0], sharesIn);
            onSuccessInvariantsGeneral(poolsToUpdate);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function previewAddLiquidityPostconditions(bool success, bytes memory returnData) internal {
        if (success) {
            onSuccessInvariantsGeneral(new address[](0));
        } else {
            invariant_LIQ_10();
            onFailInvariantsGeneral(returnData);
        }
    }

    function previewRemoveLiquidityPostconditions(bool success, bytes memory returnData, address pool) internal {
        if (success) {
            onSuccessInvariantsGeneral(new address[](0));
        } else {
            invariant_LIQ_11(pool);
            onFailInvariantsGeneral(returnData);
        }
    }

    function sellBaseETHForTokensPostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address[] memory poolsToUpdate
    ) internal {
        if (success) {
            _after(actorsToUpdate, poolsToUpdate);
            onSuccessInvariantsGeneral(poolsToUpdate);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function sellBaseTokensForETHPostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address[] memory poolsToUpdate
    ) internal {
        if (success) {
            _after(actorsToUpdate, poolsToUpdate);
            onSuccessInvariantsGeneral(poolsToUpdate);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function sellBaseTokensForTokensPostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address[] memory poolsToUpdate
    ) internal {
        if (success) {
            _after(actorsToUpdate, poolsToUpdate);
            onSuccessInvariantsGeneral(poolsToUpdate);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function sellQuoteETHForTokensPostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address[] memory poolsToUpdate
    ) internal {
        if (success) {
            _after(actorsToUpdate, poolsToUpdate);
            onSuccessInvariantsGeneral(poolsToUpdate);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function sellQuoteTokensForETHPostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address[] memory poolsToUpdate
    ) internal {
        if (success) {
            _after(actorsToUpdate, poolsToUpdate);
            onSuccessInvariantsGeneral(poolsToUpdate);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function sellQuoteTokensForTokensPostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address[] memory poolsToUpdate
    ) internal {
        if (success) {
            _after(actorsToUpdate, poolsToUpdate);
            onSuccessInvariantsGeneral(poolsToUpdate);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function swapETHForTokensPostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address[] memory poolsToUpdate,
        uint256 directions,
        uint256 minimumOut
    ) internal {
        if (success) {
            uint256 actualOut = abi.decode(returnData, (uint256));
            _after(actorsToUpdate, poolsToUpdate);

            // Get the final token out address
            directions >>= poolsToUpdate.length - 1;
            address tokenAddr;
            if (directions & 1 == 0) {
                tokenAddr = IMagicLP(poolsToUpdate[poolsToUpdate.length - 1])._BASE_TOKEN_();
            } else {
                tokenAddr = IMagicLP(poolsToUpdate[poolsToUpdate.length - 1])._QUOTE_TOKEN_();
            }

            invariant_SWAP_01(address(0), address(weth), true);
            invariant_SWAP_02(address(0), tokenAddr, false);
            invariant_SWAP_03(actualOut, minimumOut);
            onSuccessInvariantsGeneral(poolsToUpdate);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function swapTokensForETHPostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address[] memory poolsToUpdate,
        uint256 directions,
        uint256 minimumOut
    ) internal {
        if (success) {
            uint256 actualOut = abi.decode(returnData, (uint256));
            _after(actorsToUpdate, poolsToUpdate);

            // Get the token in address
            address tokenAddr;
            if (directions & 1 == 0) {
                tokenAddr = IMagicLP(poolsToUpdate[0])._BASE_TOKEN_();
            } else {
                tokenAddr = IMagicLP(poolsToUpdate[0])._QUOTE_TOKEN_();
            }

            invariant_SWAP_01(tokenAddr, address(0), false);
            invariant_SWAP_02(address(weth), address(weth), true);
            invariant_SWAP_03(actualOut, minimumOut);
            onSuccessInvariantsGeneral(poolsToUpdate);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }

    function swapTokensForTokensPostconditions(
        bool success,
        bytes memory returnData,
        address[] memory actorsToUpdate,
        address[] memory poolsToUpdate,
        uint256 directions,
        uint256 minimumOut
    ) internal {
        if (success) {
            uint256 actualOut = abi.decode(returnData, (uint256));
            _after(actorsToUpdate, poolsToUpdate);

            // Get the token in address
            address tokenInAddr;
            if (directions & 1 == 0) {
                tokenInAddr = IMagicLP(poolsToUpdate[0])._BASE_TOKEN_();
                log("post token for token swap base", tokenInAddr);
            } else {
                tokenInAddr = IMagicLP(poolsToUpdate[0])._QUOTE_TOKEN_();
                log("post token for token swap quote", tokenInAddr);
            }
            directions >>= poolsToUpdate.length - 1;

            address tokenOutAddr;
            // Get the token out address
            if (directions & 1 == 0) {
                tokenOutAddr = IMagicLP(poolsToUpdate[poolsToUpdate.length - 1])._QUOTE_TOKEN_();
                log("post token for token swap quote out", tokenOutAddr);
            } else {
                tokenOutAddr = IMagicLP(poolsToUpdate[poolsToUpdate.length - 1])._BASE_TOKEN_();
                log("post token for token swap base out", tokenOutAddr);
            }

            invariant_SWAP_01(tokenInAddr, tokenOutAddr, false);
            invariant_SWAP_02(tokenInAddr, tokenOutAddr, false);
            invariant_SWAP_03(actualOut, minimumOut);

            onSuccessInvariantsGeneral(poolsToUpdate);
        } else {
            onFailInvariantsGeneral(returnData);
        }
    }
}
