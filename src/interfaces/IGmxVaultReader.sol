pragma solidity >=0.7.0 <0.9.0;

interface IGmxVaultReader {
    function getVaultTokenInfoV3(
        address _vault,
        address _positionManager,
        address _weth,
        uint256 _usdgAmount,
        address[] memory _tokens
    ) external view returns (uint256[] memory);

    function getVaultTokenInfoV4(
        address _vault,
        address _positionManager,
        address _weth,
        uint256 _usdgAmount,
        address[] memory _tokens
    ) external view returns (uint256[] memory);
}