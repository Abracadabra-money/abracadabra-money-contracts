// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "BoringSolidity/interfaces/IERC20.sol";
import "cauldrons/CauldronV3_2.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/ICauldronV1.sol";
import "interfaces/ICauldronV2.sol";
import "interfaces/ICauldronV3.sol";

abstract contract CauldronScript {
    function deployCauldronV3MasterContract(address degenBox, address mim) public returns (ICauldronV3 cauldron) {
        cauldron = ICauldronV3(address(new CauldronV3_2(IBentoBoxV1(degenBox), IERC20(mim))));
    }

    /// Cauldron percentages parameters are in bips unit
    /// Examples:
    ///  1 = 0.01%
    ///  10_000 = 100%
    ///  250 = 2.5%
    ///
    /// Adapted from original calculation. (variables are % values instead of bips):
    ///  ltv = ltv * 1e3;
    ///  borrowFee = borrowFee * (1e5 / 100);
    ///  interest = interest * (1e18 / (365.25 * 3600 * 24) / 100);
    ///  liquidationFee = liquidationFee * 1e3 + 1e5;
    function deployCauldronV3(
        IBentoBoxV1 degenBox,
        address masterContract,
        IERC20 collateral,
        IOracle oracle,
        bytes memory oracleData,
        uint256 ltvBips,
        uint256 interestBips,
        uint256 borrowFeeBips,
        uint256 liquidationFeeBips
    ) public returns (ICauldronV3 cauldron) {
        bytes memory data = abi.encode(
            collateral,
            oracle,
            oracleData,
            uint64((interestBips * 316880878) / 100), // 316880878 is the precomputed integral part of 1e18 / (36525 * 3600 * 24)
            liquidationFeeBips * 1e1 + 1e5,
            ltvBips * 1e1,
            borrowFeeBips * 1e1
        );

        cauldron = ICauldronV3(IBentoBoxV1(degenBox).deploy(masterContract, data, true));
    }
}
