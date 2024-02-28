// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {BlastPoints} from "/blast/libraries/BlastPoints.sol";

contract BlastDapp {
    constructor() {
        BlastPoints.configure();
    }
}
