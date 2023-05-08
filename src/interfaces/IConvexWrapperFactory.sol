// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IConvexWrapperFactory {
    function CreateWrapper(uint256 _pid) external returns (address);

    function acceptPendingOwner() external;

    function owner() external view returns (address);

    function pendingOwner() external view returns (address);

    function proxyFactory() external view returns (address);

    function setImplementation(address _imp) external;

    function setPendingOwner(address _po) external;

    function wrapperImplementation() external view returns (address);
}
