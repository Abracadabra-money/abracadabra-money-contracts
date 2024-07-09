// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {ERC20} from "solady/tokens/ERC20.sol";
import {MerkleProof} from "openzeppelin-contracts/utils/cryptography/MerkleProof.sol";
import {ILzOFTV2, ILzApp, ILzCommonOFT} from "interfaces/ILayerZero.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {LzNonblockingApp} from "mixins/LzNonblockingApp.sol";
import {IMagicLP} from "/mimswap/interfaces/IMagicLP.sol";

library ChainId {
    uint256 internal constant Arbitrum = 42161;
    uint256 internal constant Blast = 81457;
}

/// @notice Bridge to bridge MIM and USDB
contract BlastMagicLPBridge is LzNonblockingApp {
    using SafeTransferLib for address;

    event LogMerkleRootChanged(bytes32 root, string ipfsMerkleProofs);
    event LogBridged(address indexed user, uint256 mimAmount, uint256 usdtAmount);
    event LogUSDTClaimed(address indexed user, uint256 amount);
    event LogSetAllowedAmount(address indexed user, uint256 amount);

    error ErrInvalidProof();
    error ErrAlreadySet();
    error ErrWrongChain();

    struct BridgeFees {
        uint128 mimFee;
        uint128 mimGas;
        uint128 usdbFee;
        uint128 usdbGas;
    }

    struct Proof {
        address user;
        uint256 amount;
        bytes32[] nodes;
    }

    struct AmountAllowed {
        bool initialized;
        uint248 amount;
    }

    uint16 public constant BLAST_LZ_CHAINID = 243;
    uint16 public constant ARBITRUM_LZ_CHAINID = 110;
    uint256 public constant BLAST_CHAINID = 81457;

    uint256 public constant USDB_DECIMALS = 18;
    uint256 public constant USDT_DECIMALS = 6;
    uint256 public constant MIM_DECIMALS = 18;
    uint256 public constant MIM_SHARED_DECIMALS = 8;

    uint256 public constant MIM_CONVERSION_RATE = 10 ** (MIM_DECIMALS - MIM_SHARED_DECIMALS);
    uint256 public constant USDB_TO_USDB_CONVERSION_RATE = 10 ** (USDB_DECIMALS - USDT_DECIMALS);

    // Blast addresses
    address public constant BLAST_LZ_ENDPOINT = 0xb6319cC6c8c27A8F5dAF0dD3DF91EA35C4720dd7;
    IMagicLP public constant LP = IMagicLP(0x163B234120aaE59b46b228d8D88f5Bc02e9baeEa);
    ILzOFTV2 public immutable MIM_OFTV2 = ILzOFTV2(0xcA8A205a579e06Cb1bE137EA3A5E5698C091f018);

    address public constant USDB = 0x4300000000000000000000000000000000000003;
    address public constant OPS_SAFE = 0x0451ADD899D63Ba6A070333550137c3e9691De7d;

    // Arbitrum addresses
    address public constant ARBITRUM_LZ_ENDPOINT = 0x3c2269811836af69497E5F486A85D7316753cf62;

    address public constant USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;

    // assume the bridge recipient is deployed with the same
    // contract address on the destination chain
    bytes32 public immutable bridgeRecipient = bytes32(uint256(uint160(address(this))));

    bytes32 public merkleRoot;
    string public ipfsMerkleProofs;
    mapping(address user => AmountAllowed amount) public amountAllowed;

    modifier onlyChain(uint256 chainid) {
        if (block.chainid != chainid) {
            revert ErrWrongChain();
        }
        _;
    }

    constructor(address _owner) LzNonblockingApp(block.chainid == BLAST_CHAINID ? BLAST_LZ_ENDPOINT : ARBITRUM_LZ_ENDPOINT, _owner) {
        trustedRemoteLookup[block.chainid == BLAST_CHAINID ? ARBITRUM_LZ_CHAINID : BLAST_LZ_CHAINID] = abi.encodePacked(
            address(this),
            address(this)
        );
    }

    ////////////////////////////////////////////////////////////////////
    /// Views
    ////////////////////////////////////////////////////////////////////

    function estimateBridgingFee() external view onlyChain(ChainId.Blast) returns (BridgeFees memory fees) {
        fees.mimGas = uint128(ILzApp(address(MIM_OFTV2)).minDstGasLookup(ARBITRUM_LZ_CHAINID, 0 /* send packet type */));
        (uint256 fee, ) = MIM_OFTV2.estimateSendFee(
            ARBITRUM_LZ_CHAINID,
            bytes32(uint256(uint160(address(this)))) /*  not required for estimation */,
            1 /* exact amount not required for estimation */,
            false,
            abi.encodePacked(uint16(1 /* message version */), uint256(fees.mimGas))
        );

        fees.mimFee = uint128(fee);

        bytes memory payload = abi.encodePacked(
            bytes32(0) /* exact recipient not required for esimation */,
            uint256(1) /* exact amount not required for estimation */
        );
        (fee, ) = lzEndpoint.estimateFees(ARBITRUM_LZ_CHAINID, address(this), payload, false, "");
        fees.usdbFee = uint128(fee);
        fees.usdbGas = fees.mimGas; // same as mim transfer should be sufficient
    }

    ////////////////////////////////////////////////////////////////////
    /// Permissionless
    ////////////////////////////////////////////////////////////////////

    function setAllowedAmount(address user, uint256 amount, bytes32[] calldata merkleProof) external onlyChain(ChainId.Blast) {
        _setAllowedAmount(user, amount, merkleProof);
    }

    function bridgeWithPermitAndProofs(
        uint256 lpAmount,
        uint256 minMIMAmount,
        uint256 minUSDBAmount,
        BridgeFees calldata fees,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s,
        Proof calldata proof
    ) external payable onlyChain(ChainId.Blast) {
        _setAllowedAmount(proof.user, proof.amount, proof.nodes);
        bridgeWithPermit(lpAmount, minMIMAmount, minUSDBAmount, fees, deadline, v, r, s);
    }

    function bridgeWithProofs(
        uint256 lpAmount,
        uint256 minMIMAmount,
        uint256 minUSDBAmount,
        BridgeFees calldata fees,
        Proof calldata proof
    ) public payable onlyChain(ChainId.Blast) returns (uint256 mimAmount, uint256 usdtAmount) {
        _setAllowedAmount(proof.user, proof.amount, proof.nodes);
        return bridge(lpAmount, minMIMAmount, minUSDBAmount, fees);
    }

    function bridgeWithPermit(
        uint256 lpAmount,
        uint256 minMIMAmount,
        uint256 minUSDBAmount,
        BridgeFees calldata fees,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public payable onlyChain(ChainId.Blast) {
        ERC20(address(LP)).permit(msg.sender, address(this), lpAmount, deadline, v, r, s);
        bridge(lpAmount, minMIMAmount, minUSDBAmount, fees);
    }

    function bridge(
        uint256 lpAmount,
        uint256 minMIMAmount,
        uint256 minUSDBAmount,
        BridgeFees calldata fees
    ) public payable onlyChain(ChainId.Blast) returns (uint256 mimAmount, uint256 usdtAmount) {
        amountAllowed[msg.sender].amount -= uint248(lpAmount);
        uint256 usdbAmount;
        address(LP).safeTransferFrom(msg.sender, address(this), lpAmount);
        (mimAmount, usdbAmount) = LP.sellShares(lpAmount, address(this), minMIMAmount, minUSDBAmount, "", block.timestamp);

        // send USDB to safe to be redeemed later on.
        USDB.safeTransfer(OPS_SAFE, usdbAmount);

        // sendFrom doesn't return the accurate mimAmount with the
        // dust removed so we are doing it here again so it's consistent with the
        // accurate usdtAmount.
        mimAmount = _removeMIMDust(mimAmount);
        usdtAmount = _convertToUSDTAmount(usdbAmount);

        // Bridge MIM
        ILzCommonOFT.LzCallParams memory lzCallParams = ILzCommonOFT.LzCallParams({
            refundAddress: payable(address(msg.sender)),
            zroPaymentAddress: address(0),
            adapterParams: abi.encodePacked(uint16(1), uint256(fees.mimGas))
        });

        MIM_OFTV2.sendFrom{value: fees.mimFee}(
            address(this), // 'from' address to send tokens
            ARBITRUM_LZ_CHAINID, // mainnet remote LayerZero chainId
            bytes32(uint256(uint160(address(msg.sender)))), // 'to' address to send tokens
            mimAmount, // amount of tokens to send (in wei)
            lzCallParams
        );

        // claim USDT on arbitrum
        _lzSend(
            ARBITRUM_LZ_CHAINID,
            abi.encode(msg.sender, usdtAmount),
            payable(msg.sender),
            address(0),
            bytes(""),
            msg.value - fees.mimFee
        );

        emit LogBridged(msg.sender, mimAmount, usdtAmount);
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

    function _nonblockingLzReceive(
        uint16 /* _srcChainId */,
        bytes memory,
        uint64,
        bytes memory _payload,
        bool
    ) internal override onlyChain(ChainId.Arbitrum) {
        (address recipient, uint256 usdtAmount) = abi.decode(_payload, (address, uint256));
        USDT.safeTransfer(recipient, usdtAmount);
        emit LogUSDTClaimed(recipient, usdtAmount);
    }

    function _removeMIMDust(uint _amount) internal view virtual returns (uint amountAfter) {
        amountAfter = _amount - (_amount % MIM_CONVERSION_RATE);
    }

    function _convertToUSDTAmount(uint256 _amount) internal view virtual returns (uint amountAfter) {
        return _amount / USDB_TO_USDB_CONVERSION_RATE;
    }

    ////////////////////////////////////////////////////////////////////
    /// Admin
    ////////////////////////////////////////////////////////////////////

    /// @dev some dust amount can accumulate in this contract but should be insignificant
    /// but we can recover it if needed
    function recover(address token, address recipient, uint256 amount) external onlyOwner {
        address(token).safeTransfer(recipient, amount);
    }

    function setMerkleRoot(bytes32 _merkleRoot, string calldata _ipfsMerkleProofs) external onlyChain(ChainId.Blast) onlyOwner {
        ipfsMerkleProofs = _ipfsMerkleProofs;
        merkleRoot = _merkleRoot;
        emit LogMerkleRootChanged(_merkleRoot, _ipfsMerkleProofs);
    }
}
