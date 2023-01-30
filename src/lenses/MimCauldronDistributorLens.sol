// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "solmate/utils/FixedPointMathLib.sol";
import "interfaces/IGlpWrapperHarvestor.sol";
import "interfaces/IMimCauldronDistributor.sol";

contract MimCauldronDistributorLens {
    error ErrCauldronNotFound(address);

    uint256 internal constant MAX_UINT256 = 2**256 - 1;

    uint256 internal constant WAD = 1e18; // The scalar of ETH and most ERC20s.

    IGlpWrapperHarvestor public immutable harvestor;

    constructor(IGlpWrapperHarvestor _harvestor) {
        harvestor = _harvestor;
    }

    // returns the apy in bips scaled by 1e18
    function getCaulronTargetApy(address _cauldron) external view returns (uint256) {
        IMimCauldronDistributor distributor = harvestor.distributor();
        uint256 cauldronInfoCount = distributor.getCauldronInfoCount();

        for (uint256 i = 0; i < cauldronInfoCount; ) {
            (address cauldron, uint256 targetApyPerSecond, , , , , , ) = distributor.cauldronInfos(i);

            if (cauldron == _cauldron) {
                return FixedPointMathLib.mulWadUp(targetApyPerSecond, 365 days);
            }

            // for the meme.
            unchecked {
                ++i;
            }
        }

        revert ErrCauldronNotFound(_cauldron);
    }
}
