// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {IBlast, IERC20Rebasing, YieldMode, GasMode} from "interfaces/IBlast.sol";

library BlastYields {
    event LogBlastGasClaimed(address indexed recipient, uint256 amount);
    event LogBlastETHClaimed(address indexed recipient, uint256 amount);
    event LogBlastTokenClaimed(address indexed recipient, address indexed token, uint256 amount);
    event LogBlastTokenClaimableEnabled(address indexed contractAddress, address indexed token);
    event LogBlastNativeClaimableEnabled(address indexed contractAddress);

    IBlast constant BLAST_YIELD_PRECOMPILE = IBlast(0x4300000000000000000000000000000000000002);

    function claimAllGasYields(address recipient) internal returns (uint256) {
        return claimAllGasYields(address(this), recipient);
    }

    function claimAllNativeYields(address recipient) internal returns (uint256 amount) {
        return claimAllNativeYields(address(this), recipient);
    }

    function claimAllGasYields(address contractAddress, address recipient) internal returns (uint256 amount) {
        amount = BLAST_YIELD_PRECOMPILE.claimAllGas(contractAddress, recipient);
        emit LogBlastGasClaimed(recipient, amount);
    }

    function claimAllNativeYields(address contractAddress, address recipient) internal returns (uint256 amount) {
        amount = BLAST_YIELD_PRECOMPILE.claimAllYield(contractAddress, recipient);
        emit LogBlastETHClaimed(recipient, amount);
    }

    function claimNativeYields(address recipient, uint256 amount) internal returns (uint256) {
        return claimNativeYields(address(this), amount, recipient);
    }

    function claimNativeYields(address contractAddress, uint256 amount, address recipient) internal returns (uint256) {
        amount = BLAST_YIELD_PRECOMPILE.claimYield(contractAddress, recipient, amount);
        emit LogBlastETHClaimed(recipient, amount);
        return amount;
    }

    function claimAllTokenYields(address token, address recipient) internal returns (uint256 amount) {
        amount = IERC20Rebasing(token).claim(recipient, IERC20Rebasing(token).getClaimableAmount(address(this)));
        emit LogBlastTokenClaimed(recipient, address(token), amount);
    }

    function claimTokenYields(address token, uint256 amount, address recipient) internal returns (uint256) {
        amount = IERC20Rebasing(token).claim(recipient, amount);
        emit LogBlastTokenClaimed(recipient, address(token), amount);
        return amount;
    }

    function enableTokenClaimable(address token) internal {
        if (IERC20Rebasing(token).getConfiguration(token) == YieldMode.CLAIMABLE) {
            return;
        }

        IERC20Rebasing(token).configure(YieldMode.CLAIMABLE);
        emit LogBlastTokenClaimableEnabled(address(this), token);
    }

    function configureDefaultClaimables(address governor_) internal {
        BLAST_YIELD_PRECOMPILE.configure(YieldMode.CLAIMABLE, GasMode.CLAIMABLE, governor_);
        emit LogBlastNativeClaimableEnabled(address(this));
    }
}
