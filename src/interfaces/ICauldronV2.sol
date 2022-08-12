// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "interfaces/IOracle.sol";

interface ICauldronV2 {
    function oracle() external view returns(IOracle);

    function accrue() external;

    function withdrawFees() external;

    function accrueInfo()
        external
        view
        returns (
            uint64,
            uint128,
            uint64
        );

    function bentoBox() external returns (address);

    function setFeeTo(address newFeeTo) external;

    function feeTo() external returns (address);

    function masterContract() external returns (ICauldronV2);
}
