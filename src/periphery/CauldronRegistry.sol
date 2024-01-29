// SPDX-License-Identifier: MIT
pragma solidity >=0.8;

import {Owned} from "solmate/auth/Owned.sol";
import {ICauldronV1} from "interfaces/ICauldronV1.sol";

contract CauldronRegistry is Owned {
    error ErrAlreadyRegistered(ICauldronV1 cauldron_);
    error ErrNotRegistered(ICauldronV1 cauldron_);
    error ErrEmptyRegistry();
    error ErrTooManyCauldrons();
    error ErrInvalidCauldron(ICauldronV1 cauldron_);

    ICauldronV1[] public cauldrons;
    mapping(ICauldronV1 => uint256) internal cauldronIndicies;

    constructor(address owner_) Owned(owner_) {}

    function addCauldrons(ICauldronV1[] calldata cauldrons_) external onlyOwner {
        for (uint256 i = 0; i < cauldrons_.length; ++i) {
            ICauldronV1 cauldron = cauldrons_[i];

            if (address(cauldron) == address(0)) {
                revert ErrInvalidCauldron(cauldron);
            }

            if (cauldronIndicies[cauldron] != 0 || (cauldrons.length != 0 && cauldrons[0] == cauldron)) {
                revert ErrAlreadyRegistered(cauldron);
            }

            uint256 cauldronIndex = cauldrons.length;
            cauldrons.push(cauldron);
            cauldronIndicies[cauldron] = cauldronIndex;
        }
    }

    function removeCauldrons(ICauldronV1[] calldata cauldrons_) external onlyOwner {
        if (cauldrons.length == 0) {
            revert ErrEmptyRegistry();
        }

        if (cauldrons.length < cauldrons_.length) {
            revert ErrTooManyCauldrons();
        }

        for (uint256 i = 0; i < cauldrons_.length; ++i) {
            ICauldronV1 cauldron = cauldrons_[i];

            if (address(cauldron) == address(0)) {
                revert ErrInvalidCauldron(cauldron);
            }

            uint256 cauldronIndex = cauldronIndicies[cauldron];
            if (cauldronIndex == 0 && cauldrons[0] != cauldron) {
                revert ErrNotRegistered(cauldron);
            }

            uint256 lastIndex = cauldrons.length - 1;
            if (cauldronIndex == lastIndex) {
                cauldrons.pop();
                delete cauldronIndicies[cauldron];
            } else {
                cauldronIndicies[cauldrons[lastIndex]] = cauldronIndex;
                cauldrons[cauldronIndex] = cauldrons[lastIndex];
                cauldrons.pop();
                delete cauldronIndicies[cauldron];
            }
        }
    }

    function cauldronsLength() public view returns (uint256) {
        return cauldrons.length;
    }
}
