// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8;

import {ILzCommonOFT, ILzApp, ILzOFTV2} from "@abracadabra-oftv2/interfaces/ILayerZero.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {OwnableOperators} from "/mixins/OwnableOperators.sol";
import {TokenAmount, IRewardHandler} from "/staking/MultiRewards.sol";

struct MultiRewardsClaimingHandlerParam {
    uint128 fee;
    uint112 gas;
    uint16 dstChainId;
}

contract MultiRewardsClaimingHandler is IRewardHandler, OwnableOperators {
    using SafeTransferLib for address;

    event LogRewardInfoSet(address token, address oft);
    event LogRescueTokens(address token, address to, uint256 amount);

    error ErrUnsupportedToken();
    error ErrNotEnoughNativeTokenToCoverFee();
    error ErrZeroAddress();
    error ErrInvalidParams();

    uint16 public constant MESSAGE_VERSION = 1;
    uint16 public constant LOCAL_CHAIN_ID = 0;

    mapping(address token => ILzOFTV2 oft) public tokenOfts;

    constructor(address _owner) {
        _initializeOwner(_owner);
    }

    ////////////////////////////////////////////////////////////////////
    /// Views
    ////////////////////////////////////////////////////////////////////

    function estimateBridgingFee(
        address _token,
        uint16 _dstChainId
    ) external view returns (uint256 fee, uint256 gas, MultiRewardsClaimingHandlerParam memory param) {
        ILzOFTV2 oft = tokenOfts[_token];
        if (oft == ILzOFTV2(address(0))) {
            revert ErrUnsupportedToken();
        }

        gas = ILzApp(address(oft)).minDstGasLookup(_dstChainId, 0 /* packet type for sendFrom */);
        (fee, ) = oft.estimateSendFee(
            _dstChainId,
            bytes32(0) /* recipient: unused */,
            uint256(1) /* amount: unused */,
            false /* useZro: unused */,
            abi.encodePacked(uint16(1), uint256(gas))
        );
        param = MultiRewardsClaimingHandlerParam({fee: uint128(fee), gas: uint112(gas), dstChainId: _dstChainId});
    }

    ////////////////////////////////////////////////////////////////////
    /// Operators
    ////////////////////////////////////////////////////////////////////

    function notifyRewards(
        address _to,
        address _refundTo,
        TokenAmount[] memory _rewards,
        bytes memory _data
    ) external payable onlyOperators {
        MultiRewardsClaimingHandlerParam[] memory _params = abi.decode(_data, (MultiRewardsClaimingHandlerParam[]));

        if (_params.length != _rewards.length) {
            revert ErrInvalidParams();
        }

        for (uint256 i = 0; i < _rewards.length; i++) {
            address token = _rewards[i].token;
            uint256 amount = _rewards[i].amount;

            if (token == address(0) || amount == 0) {
                continue;
            }

            ILzOFTV2 oft = tokenOfts[token];
            MultiRewardsClaimingHandlerParam memory param = _params[i];

            // local reward claiming when the destination is the local chain
            if (param.dstChainId == LOCAL_CHAIN_ID) {
                token.safeTransfer(_to, amount);
                continue;
            }

            if (param.fee > address(this).balance) {
                revert ErrNotEnoughNativeTokenToCoverFee();
            }

            ILzCommonOFT.LzCallParams memory lzCallParams = ILzCommonOFT.LzCallParams({
                refundAddress: payable(_refundTo),
                zroPaymentAddress: address(0),
                adapterParams: abi.encodePacked(MESSAGE_VERSION, uint256(param.gas))
            });

            oft.sendFrom{value: param.fee}(
                address(this), // 'from' address to send tokens
                param.dstChainId, // remote LayerZero chainId
                bytes32(uint256(uint160(address(_to)))), // recipient address
                amount, // amount of tokens to send (in wei)
                lzCallParams
            );
        }
    }

    ////////////////////////////////////////////////////////////////////
    /// Admin
    ////////////////////////////////////////////////////////////////////

    function setRewardInfo(address _token, ILzOFTV2 _oft) external onlyOwner {
        if (_oft != ILzOFTV2(address(0))) {
            _token.safeApprove(address(_oft), type(uint256).max);
        }

        tokenOfts[_token] = _oft;
        emit LogRewardInfoSet(_token, address(_oft));
    }

    function rescueTokens(address _token, address _to, uint256 _amount) external onlyOwner {
        if (_token == address(0)) {
            SafeTransferLib.safeTransferETH(_to, _amount);
        } else {
            _token.safeTransfer(_to, _amount);
        }
        emit LogRescueTokens(_token, _to, _amount);
    }
}
