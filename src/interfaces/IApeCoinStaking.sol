// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IApeCoinStaking {
    function depositApeCoin(uint256 _amount, address _recipient) external;

    function claimApeCoin(address _recipient) external;

    function pendingRewards(
        uint256 _poolId,
        address _address,
        uint256 _tokenId
    ) external view returns (uint256);

    function stakedTotal(address _address) external view returns (uint256);

    function withdrawApeCoin(uint256 _amount, address _recipient) external;
}
