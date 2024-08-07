// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {OwnableOperators} from "/mixins/OwnableOperators.sol";
import {IGelatoChecker} from "/interfaces/IGelatoChecker.sol";
import {IBentoBoxV1} from "/interfaces/IBentoBoxV1.sol";
import {ICauldronV2} from "/interfaces/ICauldronV2.sol";
import {IERC20} from "@BoringSolidity/interfaces/IERC20.sol";
import {CauldronRegistry, CauldronInfo} from "/periphery/CauldronRegistry.sol";
import {CauldronOwner} from "/periphery/CauldronOwner.sol";

contract CauldronReducer is OwnableOperators, IGelatoChecker {
    event LogMaxBalanceChanged(uint256 _maxBalance);

    error ErrCauldronNotEligibleForReduction(ICauldronV2 _cauldron);

    CauldronOwner public immutable cauldronOwner;
    IERC20 public immutable mim;

    uint256 public maxBalance;

    constructor(address _owner, CauldronOwner _cauldronOwner, IERC20 _mim, uint256 _maxBalance) {
        cauldronOwner = _cauldronOwner;
        mim = _mim;

        _initializeOwner(_owner);
        _setMaxBalance(_maxBalance);
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// OPERATORS
    //////////////////////////////////////////////////////////////////////////////////////

    function reduceCompletely(ICauldronV2[] calldata _cauldrons) external onlyOperators {
        CauldronRegistry cauldronRegistry = cauldronOwner.registry();

        for (uint256 i = 0; i < _cauldrons.length; ++i) {
            address cauldron = address(_cauldrons[i]);
            CauldronInfo memory cauldronInfo = cauldronRegistry.get(cauldron);
            if (!_shouldReduceCompletely(cauldronInfo)) {
                revert ErrCauldronNotEligibleForReduction(ICauldronV2(cauldron));
            }

            cauldronOwner.reduceCompletely(ICauldronV2(cauldron));
        }
    }

    //////////////////////////////////////////////////////////////////////////////////////
    /// VIEWS
    //////////////////////////////////////////////////////////////////////////////////////

    function checker() external view override returns (bool canExec, bytes memory execPayload) {
        CauldronRegistry cauldronRegistry = cauldronOwner.registry();

        uint256 cauldronsLength = cauldronRegistry.length();

        uint256 numToUpdate = 0;
        ICauldronV2[] memory toBeUpdated = new ICauldronV2[](cauldronsLength);

        for (uint256 i = 0; i < cauldronsLength; ++i) {
            CauldronInfo memory cauldronInfo = cauldronRegistry.get(i);

            if (_shouldReduceCompletely(cauldronInfo)) {
                canExec = true;
                unchecked {
                    toBeUpdated[numToUpdate++] = ICauldronV2(cauldronInfo.cauldron);
                }
            }
        }

        ICauldronV2[] memory toBeUpdatedShrunk = new ICauldronV2[](numToUpdate);

        for (; numToUpdate > 0; ) {
            unchecked {
                --numToUpdate;
            }
            toBeUpdatedShrunk[numToUpdate] = toBeUpdated[numToUpdate];
        }

        execPayload = abi.encodeCall(CauldronReducer.reduceCompletely, (toBeUpdatedShrunk));
    }

    /////////////////////////////////////////////////////////////////////////////////
    // INTERNALS
    /////////////////////////////////////////////////////////////////////////////////

    function _shouldReduceCompletely(CauldronInfo memory _cauldronInfo) internal view returns (bool shouldReduce) {
        if (!_cauldronInfo.deprecated) {
            return false;
        }

        IBentoBoxV1 bentoBox = IBentoBoxV1(ICauldronV2(_cauldronInfo.cauldron).bentoBox());
        uint256 balance = bentoBox.toAmount(mim, bentoBox.balanceOf(mim, address(_cauldronInfo.cauldron)), true);

        return balance > maxBalance;
    }

    function _setMaxBalance(uint256 _maxBalance) internal {
        maxBalance = _maxBalance;
        emit LogMaxBalanceChanged(maxBalance);
    }

    /////////////////////////////////////////////////////////////////////////////////
    // ADMIN
    /////////////////////////////////////////////////////////////////////////////////

    function setMaxBalance(uint256 _maxBalance) external onlyOwner {
        _setMaxBalance(_maxBalance);
    }
}
