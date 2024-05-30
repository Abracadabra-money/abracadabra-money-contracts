// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {IBlastPoints} from "interfaces/IBlast.sol";

library BlastPoints {
    address public constant BLAST_POINTS_OPERATOR = 0xD1025F1359422Ca16D9084908d629E0dBa60ff28;
    IBlastPoints public constant BLAST_POINTS = IBlastPoints(0x2536FE9ab3F511540F2f9e2eC2A805005C3Dd800);

    function configure() internal {
        BLAST_POINTS.configurePointsOperator(BLAST_POINTS_OPERATOR);
    }
}
