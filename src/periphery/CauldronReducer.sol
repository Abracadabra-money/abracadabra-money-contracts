// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {OwnableOperators} from "/mixins/OwnableOperators.sol";
import {IGelatoChecker} from "/interfaces/IGelatoChecker.sol";
import {IBentoBoxLite} from "/interfaces/IBentoBoxV1.sol";
import {ICauldronV2} from "/interfaces/ICauldronV2.sol";
import {CauldronRegistry, CauldronInfo} from "/periphery/CauldronRegistry.sol";
import {CauldronOwner} from "/periphery/CauldronOwner.sol";

contract CauldronReducer is OwnableOperators, IGelatoChecker {
    event LogMaxBalanceChanged(uint256 _maxBalance);

    error ErrCauldronNotEligibleForReduction(ICauldronV2 _cauldron);

    CauldronOwner public immutable cauldronOwner;
    address public immutable mim;

    uint256 public maxBalance;

    constructor(CauldronOwner _cauldronOwner, address _mim, address _owner) {
        cauldronOwner = _cauldronOwner;
        mim = _mim;

        _initializeOwner(_owner);
        maxBalance = type(uint256).max;
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

        IBentoBoxLite bentoBox = IBentoBoxLite(ICauldronV2(_cauldronInfo.cauldron).bentoBox());
        uint256 balance = bentoBox.toAmount(mim, bentoBox.balanceOf(mim, address(_cauldronInfo.cauldron)), true);

        return balance > maxBalance;
    }

    /////////////////////////////////////////////////////////////////////////////////
    // ADMIN
    /////////////////////////////////////////////////////////////////////////////////

    function setMaxBalance(uint256 _maxBalance) external onlyOwner {
        maxBalance = _maxBalance;
        emit LogMaxBalanceChanged(maxBalance);
    }
}
