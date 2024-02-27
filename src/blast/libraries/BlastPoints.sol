// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {IBlastPoints} from "interfaces/IBlast.sol";

library BlastPoints {
    event LogBlastPointsOperatorConfigured(address indexed contractAddress, address indexed operator);

    IBlastPoints constant BLAST_POINTS = IBlastPoints(0x2fc95838c71e76ec69ff817983BFf17c710F34E0);

    function configurePointsOperator(address _pointsOperator) internal {
        BLAST_POINTS.configurePointsOperator(_pointsOperator);
        emit LogBlastPointsOperatorConfigured(address(this), _pointsOperator);
    }
}
