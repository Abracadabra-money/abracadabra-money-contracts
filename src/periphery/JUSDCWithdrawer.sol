// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {OwnableOperators} from "/mixins/OwnableOperators.sol";
import {IJonesRouter} from "/interfaces/IJonesRouter.sol";

contract JUSDCWithdrawer is OwnableOperators {
    address public immutable router;

    constructor(address _router, address _owner) {
        _initializeOwner(_owner);
        router = _router;
    }

    function withdraw(uint256 amount, address to) external onlyOperators returns (bool, uint256) {
        return IJonesRouter(router).withdrawRequest(amount, to, 0, "");
    }
}
