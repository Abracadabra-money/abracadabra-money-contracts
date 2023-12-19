// SPDX-License-Identifier: MIT
/// solhint-disable not-rely-on-time
pragma solidity >=0.8.0;

import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {ERC20} from "BoringSolidity/ERC20.sol";
import {BoringERC20} from "BoringSolidity/libraries/BoringERC20.sol";
import {OperatableV2} from "mixins/OperatableV2.sol";
import {ILzReceiver, ILzApp, ILzOFTV2, ILzCommonOFT} from "interfaces/ILayerZero.sol";

/// @notice Responsible of distributing MIM rewards.
/// Mainnet Only
contract SpellStakingRewardDistributor is OperatableV2 {
    using BoringERC20 for IERC20;

    event LogSetOperator(address indexed operator, bool status);
    event LogDistribute(Distribution indexed distribution);
    error ErrNotEnoughNativeTokenToCoverFee();

    struct Distribution {
        // slot 0
        address recipient;
        uint80 gas; // lz  gas limit
        uint16 lzChainId; // lz chain id
        // slot 1
        uint128 fee; // lz fee
        uint128 amount;
    }

    ERC20 public constant MIM = ERC20(0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3);
    ILzOFTV2 public constant OFT = ILzOFTV2(0x439a5f0f5E8d149DDA9a0Ca367D4a8e4D6f83C10);

    constructor(address _owner) OperatableV2(_owner) {
        MIM.approve(address(OFT), type(uint256).max);
    }

    receive() external payable {}

    function estimateBridgingFee(uint256 amount, uint16 lzChainId, address recipient) external view returns (uint256 fee, uint256 gas) {
        gas = ILzApp(address(OFT)).minDstGasLookup(lzChainId, 0 /* packet type for sendFrom */);

        (fee, ) = OFT.estimateSendFee(
            lzChainId,
            bytes32(uint256(uint160(recipient))),
            amount,
            false,
            abi.encodePacked(uint16(1), uint256(gas))
        );
    }

    function distribute(Distribution[] calldata distributions) external onlyOperators {
        uint256 length = distributions.length;
        for (uint256 i = 0; length > i; ) {
            Distribution memory distribution = distributions[i];

            if (distribution.fee > 0) {
                // optionnal check for convenience
                // check if there is enough native token to cover the bridging fees
                if (distribution.fee > address(this).balance) {
                    revert ErrNotEnoughNativeTokenToCoverFee();
                }

                ILzCommonOFT.LzCallParams memory lzCallParams = ILzCommonOFT.LzCallParams({
                    refundAddress: payable(address(this)),
                    zroPaymentAddress: address(0),
                    adapterParams: abi.encodePacked(uint16(1), uint256(distribution.gas))
                });

                OFT.sendFrom{value: distribution.fee}(
                    address(this),
                    uint16(distribution.lzChainId),
                    bytes32(uint256(uint160(distribution.recipient))),
                    distribution.amount,
                    lzCallParams
                );
            } else {
                MIM.transfer(distribution.recipient, distribution.amount);
            }

            emit LogDistribute(distribution);

            unchecked {
                ++i;
            }
        }
    }

    ////////////////////////////////////////////////////////
    // Emergency Functions
    ////////////////////////////////////////////////////////

    function rescueTokens(IERC20 token, address to, uint256 amount) external onlyOwner {
        token.safeTransfer(to, amount);
    }

    function execute(address to, uint256 value, bytes calldata data) external onlyOwner returns (bool success, bytes memory result) {
        // solhint-disable-next-line avoid-low-level-calls
        (success, result) = to.call{value: value}(data);
    }
}
