// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8;

import {ILzCommonOFT, ILzApp, ILzOFTV2} from "@abracadabra-oftv2/interfaces/ILayerZero.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {OwnableOperators} from "/mixins/OwnableOperators.sol";
import {TokenAmount, IRewardHandler} from "/staking/MultiRewards.sol";

struct MultiRewardsClaimingHandlerParam {
    address token;
    uint128 fee;
    uint112 gas;
    uint16 dstChainId;
}

struct RewardInfo {
    address token;
    ILzOFTV2 oft;
}

contract MultiRewardsClaimingHandler is IRewardHandler, OwnableOperators {
    using SafeTransferLib for address;

    event LogRewardInfoSet(address token, address oft);
    event LogRescueTokens(address token, address to, uint256 amount);
    
    error ErrUnsupportedToken();
    error ErrNotEnoughNativeTokenToCoverFee();
    error ErrZeroAddress();

    uint16 public constant MESSAGE_VERSION = 1;

    mapping(address user => mapping(address token => uint256 amount)) public balanceOf;
    mapping(address token => RewardInfo info) public rewardInfo;

    constructor(address _owner) {
        _initializeOwner(_owner);
    }

    function claimRewards(address[] memory _tokens) external {
        for (uint256 i = 0; i < _tokens.length; i++) {
            _claimRewardsLocal(msg.sender, _tokens[i]);
        }
    }

    function claimRewards(MultiRewardsClaimingHandlerParam[] memory _params) public {
        _claimRewards(msg.sender, _params);
    }

    ////////////////////////////////////////////////////////////////////
    /// Views
    ////////////////////////////////////////////////////////////////////

    function estimateBridgingFee(address _token, uint16 _dstChainId) external view returns (uint256 fee, uint256 gas, bytes memory data) {
        ILzOFTV2 oft = rewardInfo[_token].oft;
        if (oft == ILzOFTV2(address(0))) {
            revert ErrUnsupportedToken();
        }

        gas = ILzApp(address(oft)).minDstGasLookup(_dstChainId, 0 /* packet type for sendFrom */);
        (fee, ) = oft.estimateSendFee(_dstChainId, bytes32(0), uint256(1), false, abi.encodePacked(uint16(1), uint256(gas)));
        data = abi.encode(MultiRewardsClaimingHandlerParam({token: _token, fee: uint128(fee), gas: uint112(gas), dstChainId: _dstChainId}));
    }

    ////////////////////////////////////////////////////////////////////
    /// Operators
    ////////////////////////////////////////////////////////////////////

    function notifyRewards(address _user, TokenAmount[] memory _rewards, bytes memory _data) external payable onlyOperators {
        for (uint256 i = 0; i < _rewards.length; i++) {
            if (_rewards[i].amount == 0) {
                continue;
            }

            address token = _rewards[i].token;
            balanceOf[_user][token] += _rewards[i].amount;
            token.safeTransferFrom(msg.sender, address(this), _rewards[i].amount);
        }

        if (_data.length > 0) {
            _claimRewards(_user, abi.decode(_data, (MultiRewardsClaimingHandlerParam[])));
        }
    }

    ////////////////////////////////////////////////////////////////////
    /// Admin
    ////////////////////////////////////////////////////////////////////

    function setRewardInfo(address _token, ILzOFTV2 _oft) external onlyOwner {
        rewardInfo[_token] = RewardInfo({token: _token, oft: _oft});
        emit LogRewardInfoSet(_token, address(_oft));
    }

    function rescueTokens(address _token, address _to, uint256 _amount) external onlyOwner {
        _token.safeTransfer(_to, _amount);
        emit LogRescueTokens(_token, _to, _amount);
    }

    ////////////////////////////////////////////////////////////////////
    /// Internals
    ////////////////////////////////////////////////////////////////////

    function _claimRewards(address _user, MultiRewardsClaimingHandlerParam[] memory _params) internal {
        for (uint256 i = 0; i < _params.length; i++) {
            MultiRewardsClaimingHandlerParam memory param = _params[i];

            if (param.dstChainId == 0) {
                _claimRewardsLocal(_user, param.token);
                continue;
            }

            if (param.fee > address(this).balance) {
                revert ErrNotEnoughNativeTokenToCoverFee();
            }

            RewardInfo memory info = rewardInfo[param.token];
            if (info.oft == ILzOFTV2(address(0))) {
                revert ErrUnsupportedToken();
            }

            uint256 amount = balanceOf[_user][param.token];
            balanceOf[_user][param.token] = 0;

            ILzCommonOFT.LzCallParams memory lzCallParams = ILzCommonOFT.LzCallParams({
                refundAddress: payable(_user),
                zroPaymentAddress: address(0),
                adapterParams: abi.encodePacked(MESSAGE_VERSION, uint256(param.gas))
            });

            info.oft.sendFrom{value: param.fee}(
                address(this), // 'from' address to send tokens
                param.dstChainId, // mainnet remote LayerZero chainId
                bytes32(uint256(uint160(address(_user)))), // 'to' address to send tokens
                amount, // amount of tokens to send (in wei)
                lzCallParams
            );
        }
    }

    function _claimRewardsLocal(address _user, address _token) internal {
        uint256 _amount = balanceOf[_user][_token];
        balanceOf[_user][_token] = 0;

        _token.safeTransfer(_user, _amount);
    }
}
