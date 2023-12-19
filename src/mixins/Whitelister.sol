// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {MerkleProof} from "openzeppelin-contracts/utils/cryptography/MerkleProof.sol";
import {BoringOwnable} from "BoringSolidity/BoringOwnable.sol";
import {IWhitelister} from "interfaces/IWhitelister.sol";

contract Whitelister is IWhitelister, BoringOwnable {
    event LogSetMaxBorrow(address user, uint256 maxBorrowAmount);
    event LogSetMerkleRoot(bytes32 newRoot, string ipfsMerkleProofs);
    mapping(address => uint256) public amountAllowed;

    bytes32 public merkleRoot;
    string public ipfsMerkleProofs;

    constructor(bytes32 _merkleRoot, string memory _ipfsMerkleProofs) {
        merkleRoot = _merkleRoot;
        ipfsMerkleProofs = _ipfsMerkleProofs;
        emit LogSetMerkleRoot(_merkleRoot, _ipfsMerkleProofs);
    }

    function setMaxBorrowOwner(address user, uint256 maxBorrow) external onlyOwner {
        amountAllowed[user] = maxBorrow;

        emit LogSetMaxBorrow(user, maxBorrow);
    }

    /// @inheritdoc IWhitelister
    function isBorrowingAllowed(address user, uint256 newBorrowAmount) external view override returns (bool success) {
        return amountAllowed[user] >= newBorrowAmount;
    }

    /// @inheritdoc IWhitelister
    function setMaxBorrow(address user, uint256 maxBorrow, bytes32[] calldata merkleProof) external returns (bool success) {
        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(user, maxBorrow));
        require(MerkleProof.verify(merkleProof, merkleRoot, node), "Whitelister: Invalid proof.");

        amountAllowed[user] = maxBorrow;

        emit LogSetMaxBorrow(user, maxBorrow);

        return true;
    }

    function changeMerkleRoot(bytes32 newRoot, string calldata ipfsMerkleProofs_) external onlyOwner {
        ipfsMerkleProofs = ipfsMerkleProofs_;
        merkleRoot = newRoot;
        emit LogSetMerkleRoot(newRoot, ipfsMerkleProofs_);
    }
}
