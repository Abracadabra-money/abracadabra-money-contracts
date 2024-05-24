// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {OperatableV2} from "mixins/OperatableV2.sol";

struct CauldronInfo {
    address cauldron;
    uint8 version;
    bool deprecated;
}

contract CauldronRegistry is OperatableV2 {
    event LogCauldronRegistered(address indexed cauldron, uint8 version, bool deprecated);
    event LogCauldronRemoved(address indexed cauldron);
    event LogCauldronDeprecated(address indexed cauldron, bool deprecated);

    error ErrAlreadyRegistered(address cauldron_);
    error ErrNotRegistered(address cauldron_);
    error ErrEmptyRegistry();
    error ErrTooManyCauldrons();
    error ErrInvalidCauldron(address cauldron_);

    CauldronInfo[] public cauldrons;
    mapping(address => uint256) internal cauldronIndicies;

    constructor(address owner_) OperatableV2(owner_) {}

    ///////////////////////////////////////////////////////////////////////////////////
    // VIEWS
    ///////////////////////////////////////////////////////////////////////////////////

    function length() public view returns (uint256) {
        return cauldrons.length;
    }

    function get(address cauldron_) public view returns (CauldronInfo memory) {
        uint256 cauldronIndex = cauldronIndicies[cauldron_];
        if (!registered(cauldron_)) {
            revert ErrNotRegistered(cauldron_);
        }

        return cauldrons[cauldronIndex];
    }

    function registered(address cauldron_) public view returns (bool) {
        return cauldronIndicies[cauldron_] != 0 || (cauldrons.length != 0 && cauldrons[0].cauldron == cauldron_);
    }

    function get(uint256 index_) public view returns (CauldronInfo memory) {
        if (index_ >= cauldrons.length) {
            revert ErrNotRegistered(address(0));
        }

        return cauldrons[index_];
    }

    function isDeprecated(address cauldron_) public view returns (bool) {
        return get(cauldron_).deprecated;
    }

    ///////////////////////////////////////////////////////////////////////////////////
    // OPERATORS
    ///////////////////////////////////////////////////////////////////////////////////

    function add(CauldronInfo[] calldata items_) external onlyOperators {
        for (uint256 i = 0; i < items_.length; ++i) {
            CauldronInfo memory item = items_[i];

            if (item.cauldron == address(0)) {
                revert ErrInvalidCauldron(item.cauldron);
            }

            if (registered(item.cauldron)) {
                revert ErrAlreadyRegistered(item.cauldron);
            }

            uint256 cauldronIndex = cauldrons.length;
            cauldrons.push(item);
            cauldronIndicies[item.cauldron] = cauldronIndex;

            emit LogCauldronRegistered(item.cauldron, item.version, item.deprecated);
        }
    }

    function setDeprecated(address cauldron_, bool deprecated_) external onlyOperators {
        if (!registered(cauldron_)) {
            revert ErrNotRegistered(cauldron_);
        }

        cauldrons[cauldronIndicies[cauldron_]].deprecated = deprecated_;
        emit LogCauldronDeprecated(cauldron_, deprecated_);
    }

    function remove(address[] calldata cauldrons_) external onlyOperators {
        if (cauldrons.length == 0) {
            revert ErrEmptyRegistry();
        }

        if (cauldrons.length < cauldrons_.length) {
            revert ErrTooManyCauldrons();
        }

        for (uint256 i = 0; i < cauldrons_.length; ++i) {
            address cauldron = cauldrons_[i];

            if (address(cauldron) == address(0)) {
                revert ErrInvalidCauldron(cauldron);
            }

            uint256 cauldronIndex = cauldronIndicies[cauldron];
            if (cauldronIndex == 0 && cauldrons[0].cauldron != cauldron) {
                revert ErrNotRegistered(cauldron);
            }

            uint256 lastIndex = cauldrons.length - 1;
            if (cauldronIndex == lastIndex) {
                cauldrons.pop();
                delete cauldronIndicies[cauldron];
                emit LogCauldronRemoved(cauldron);
            } else {
                cauldronIndicies[cauldrons[lastIndex].cauldron] = cauldronIndex;
                cauldrons[cauldronIndex] = cauldrons[lastIndex];
                cauldrons.pop();
                delete cauldronIndicies[cauldron];
                emit LogCauldronRemoved(cauldron);
            }
        }
    }
}
