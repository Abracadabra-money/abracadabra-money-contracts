// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {MerkleProof} from "openzeppelin-contracts/utils/cryptography/MerkleProof.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {BoringOwnable} from "BoringSolidity/BoringOwnable.sol";


/// @notice Redeem Potion Points
contract PotionPointRedeemer is BoringOwnable {
    using SafeTransferLib for address;

    event LogMerkleRootChanged(bytes32 root, string ipfsMerkleProofs);
    event LogSetAllowedAmount(address indexed user, uint256 amount);

    error ErrInvalidProof();
    error ErrAlreadySet();

    struct DistributeToken {
        address token;
        uint256 amount;
    }

    DistributeToken[] public distributions;

    struct Proof {
        address user;
        uint256 amount;
        bytes32[] nodes;
    }

    struct AmountAllowed {
        bool initialized;
        uint248 amount;
    }

    // assume the bridge recipient is deployed with the same
    // contract address on the destination chain
    bytes32 public immutable bridgeRecipient = bytes32(uint256(uint160(address(this))));

    bytes32 public merkleRoot;
    string public ipfsMerkleProofs;
    mapping(address user => AmountAllowed amount) public amountAllowed;
    uint256 public immutable TOTAL_POINTS;

    constructor(uint256 total) {
        TOTAL_POINTS = total;
    }

    function addDistribution(address token, uint256 amount) public onlyOwner {
        token.safeTransferFrom(msg.sender, address(this), amount);
        distributions.push(DistributeToken(token, amount));
    }

    ////////////////////////////////////////////////////////////////////
    /// Permissionless
    ////////////////////////////////////////////////////////////////////

    function setAllowedAmount(address user, uint256 amount, bytes32[] calldata merkleProof) external {
        _setAllowedAmount(user, amount, merkleProof);
    }

    function redeemWithProofs(Proof calldata proof) public {
        _setAllowedAmount(proof.user, proof.amount, proof.nodes);
        redeem();
    }

    function redeem() public {
        uint256 amountPoints = uint256(amountAllowed[msg.sender].amount);
        amountAllowed[msg.sender].amount -= amountAllowed[msg.sender].amount;
        for(uint i; i < distributions.length; i++) {
            uint256 amount = distributions[i].amount;
            distributions[i].token.safeTransfer(msg.sender, amount * amountPoints / TOTAL_POINTS);
        }
    }

    ////////////////////////////////////////////////////////////////////
    // Internal
    ////////////////////////////////////////////////////////////////////

    function _setAllowedAmount(address user, uint256 amount, bytes32[] calldata merkleProof) internal {
        if (amountAllowed[user].initialized) {
            revert ErrAlreadySet();
        }

        bytes32 node = keccak256(abi.encodePacked(user, amount));
        if (!MerkleProof.verify(merkleProof, merkleRoot, node)) {
            revert ErrInvalidProof();
        }

        amountAllowed[user] = AmountAllowed(true, uint248(amount));
        emit LogSetAllowedAmount(user, amount);
    }

    ////////////////////////////////////////////////////////////////////
    /// Admin
    ////////////////////////////////////////////////////////////////////

    /// @dev some dust amount can accumulate in this contract but should be insignificant
    /// but we can recover it if needed
    function recover(address token, address recipient, uint256 amount) external onlyOwner {
        address(token).safeTransfer(recipient, amount);
    }

    function setMerkleRoot(bytes32 _merkleRoot, string calldata _ipfsMerkleProofs) external onlyOwner {
        ipfsMerkleProofs = _ipfsMerkleProofs;
        merkleRoot = _merkleRoot;
        emit LogMerkleRootChanged(_merkleRoot, _ipfsMerkleProofs);
    }
}
