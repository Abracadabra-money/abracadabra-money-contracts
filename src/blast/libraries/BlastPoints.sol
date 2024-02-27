// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {IBlastPoints} from "interfaces/IBlast.sol";

library BlastPoints {
    event LogBlastPointsOperatorConfigured(address indexed contractAddress, address indexed operator);

    address constant BLAST_POINTS_OPERATOR = 0xD1025F1359422Ca16D9084908d629E0dBa60ff28;
    IBlastPoints constant BLAST_POINTS = IBlastPoints(0x2fc95838c71e76ec69ff817983BFf17c710F34E0);

    function configure() internal {
        BLAST_POINTS.configurePointsOperator(BLAST_POINTS_OPERATOR);
        emit LogBlastPointsOperatorConfigured(address(this), BLAST_POINTS_OPERATOR);
    }
}
