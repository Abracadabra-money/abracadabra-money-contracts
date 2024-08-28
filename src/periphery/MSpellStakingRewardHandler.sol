// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8;

import {ILzCommonOFT, ILzApp, ILzOFTV2} from "@abracadabra-oftv2/interfaces/ILayerZero.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {OwnableOperators} from "/mixins/OwnableOperators.sol";
import {IRewardHandler} from "/staking/MSpellStaking.sol";

struct MSpellStakingRewardHandlerParam {
    uint128 fee;
    uint112 gas;
    uint16 dstChainId;
}

contract MSpellStakingRewardHandler is IRewardHandler, OwnableOperators {
    using SafeTransferLib for address;

    error ErrUnsupportedToken();
    error ErrNotEnoughNativeTokenToCoverFee();
    error ErrZeroAddress();

    mapping(address user => uint256 amount) public balanceOf;
    address public immutable mim;
    ILzOFTV2 public immutable oft;

    constructor(address _mim, address _oft, address _owner) {
        if (_mim == address(0) || _oft == address(0)) {
            revert ErrZeroAddress();
        }

        _initializeOwner(_owner);

        mim = _mim;
        oft = ILzOFTV2(_oft);
    }

    function claimRewards() external {
        _claimRewardsLocal(msg.sender);
    }

    function claimRewards(MSpellStakingRewardHandlerParam memory _params) public {
        _claimRewards(msg.sender, _params);
    }

    ////////////////////////////////////////////////////////////////////
    /// Views
    ////////////////////////////////////////////////////////////////////

    function estimateBridgingFee(uint16 _dstChainId) external view returns (uint256 fee, uint256 gas) {
        gas = ILzApp(address(oft)).minDstGasLookup(_dstChainId, 0 /* packet type for sendFrom */);
        (fee, ) = oft.estimateSendFee(_dstChainId, bytes32(0), uint256(1), false, abi.encodePacked(uint16(1), uint256(gas)));
    }

    ////////////////////////////////////////////////////////////////////
    /// Operators
    ////////////////////////////////////////////////////////////////////

    function notifyRewards(address _user, address _token, uint256 _amount, bytes memory _data) external payable override onlyOperators {
        if (_token != mim) {
            revert ErrUnsupportedToken();
        }

        balanceOf[_user] += _amount;

        if (_data.length > 0) {
            _claimRewards(_user, abi.decode(_data, (MSpellStakingRewardHandlerParam)));
        }
    }

    ////////////////////////////////////////////////////////////////////
    /// Internals
    ////////////////////////////////////////////////////////////////////

    function _claimRewards(address _user, MSpellStakingRewardHandlerParam memory _params) internal {
        if (_params.dstChainId == 0) {
            _claimRewardsLocal(_user);
            return;
        }

        if (_params.fee > address(this).balance) {
            revert ErrNotEnoughNativeTokenToCoverFee();
        }

        uint256 amount = balanceOf[_user];
        balanceOf[_user] = 0;

        ILzCommonOFT.LzCallParams memory lzCallParams = ILzCommonOFT.LzCallParams({
            refundAddress: payable(_user),
            zroPaymentAddress: address(0),
            adapterParams: abi.encodePacked(uint16(1), uint256(_params.gas))
        });

        oft.sendFrom{value: _params.fee}(
            address(this), // 'from' address to send tokens
            _params.dstChainId, // mainnet remote LayerZero chainId
            bytes32(uint256(uint160(address(_user)))), // 'to' address to send tokens
            amount, // amount of tokens to send (in wei)
            lzCallParams
        );
    }

    function _claimRewardsLocal(address _user) internal {
        uint256 _amount = balanceOf[_user];
        balanceOf[_user] = 0;

        mim.safeTransfer(_user, _amount);
    }
}
