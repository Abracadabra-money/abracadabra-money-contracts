// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";
import {BoringERC20} from "BoringSolidity/libraries/BoringERC20.sol";
import {BoringOwnable} from "BoringSolidity/BoringOwnable.sol";
import {Address} from "openzeppelin-contracts/utils/Address.sol";
import {SafeApproveLib} from "libraries/SafeApproveLib.sol";
import {IStargatePool, IStargateRouter} from "interfaces/IStargate.sol";
import {IOracle} from "interfaces/IOracle.sol";
import {IAggregator} from "interfaces/IAggregator.sol";

contract StargateLPMIMPool is BoringOwnable {
    using BoringERC20 for IERC20;
    using SafeApproveLib for IERC20;

    error ErrSwapFailed();
    error ErrUnauthorizedRedeemer(address);
    error ErrUnauthorizedExecutor(address);
    error ErrInvalidToken(address);
    error ErrInvalidFee(uint256);

    event AllowedRedeemerChanged(address redeemer, bool allowed);
    event AllowedExecutorChanged(address redeemer, bool allowed);
    event Swap(address from, IStargatePool tokenIn, uint256 amountIn, uint256 amountOut, address recipient);
    event PoolChanged(IStargatePool lp, uint16 poolId, IOracle oracle);
    event FeeChanged(uint256 previousFeeBps, uint256 feeBps);

    struct PoolInfo {
        uint16 poolId; // 16 bits
        IOracle oracle; // 160 bits
        uint80 oracleDecimalsMultipler; // 80 bits
    }

    IERC20 public immutable mim;
    IAggregator public immutable mimOracle;
    IStargateRouter public immutable stargateRouter;

    uint256 public feeBps;

    mapping(IStargatePool => PoolInfo) public pools;
    mapping(address => bool) public allowedRedeemers;
    mapping(address => bool) public allowedExecutors;

    modifier onlyAllowedRedeemers() {
        if (!allowedRedeemers[msg.sender]) {
            revert ErrUnauthorizedRedeemer(msg.sender);
        }
        _;
    }

    modifier onlyAllowedExecutors() {
        if (!allowedExecutors[msg.sender]) {
            revert ErrUnauthorizedExecutor(msg.sender);
        }
        _;
    }

    constructor(IERC20 _mim, IAggregator _mimOracle, IStargateRouter _stargateRouter) {
        feeBps = 20;
        mim = _mim;
        mimOracle = _mimOracle;
        stargateRouter = _stargateRouter;
    }

    function swapForMim(IStargatePool tokenIn, uint256 amountIn, address recipient) external onlyAllowedRedeemers returns (uint256) {
        if (address(pools[tokenIn].oracle) == address(0)) {
            revert ErrInvalidToken(address(tokenIn));
        }

        uint256 amount = getMimAmountOut(tokenIn, amountIn);

        IERC20(address(tokenIn)).safeTransferFrom(msg.sender, address(this), amountIn);
        mim.safeTransfer(recipient, amount);

        emit Swap(msg.sender, tokenIn, amountIn, amount, recipient);

        return amount;
    }

    function getMimAmountOut(IStargatePool tokenIn, uint256 amountIn) public view returns (uint256) {
        if (address(pools[tokenIn].oracle) == address(0)) {
            revert ErrInvalidToken(address(tokenIn));
        }

        uint256 mimUsd = uint256(mimOracle.latestAnswer()); // 8 decimals

        /// @dev for oracleDecimalsMultipler = 14 and tokenIn is 6 decimals -> amountOut is 6 decimals
        uint256 amount = ((amountIn * 10 ** pools[tokenIn].oracleDecimalsMultipler) / pools[tokenIn].oracle.peekSpot("")) / mimUsd;
        return amount - ((amount * feeBps) / 10_000);
    }

    /*** Admin Functions ***/
    function setAllowedRedeemer(address redeemer, bool allowed) external onlyOwner {
        allowedRedeemers[redeemer] = allowed;
        emit AllowedRedeemerChanged(redeemer, allowed);
    }

    function setAllowedExecutor(address executor, bool allowed) external onlyOwner {
        allowedExecutors[executor] = allowed;
        emit AllowedExecutorChanged(executor, allowed);
    }

    function setFee(uint256 _feeBps) external onlyOwner {
        if (_feeBps > 10_000) {
            revert ErrInvalidFee(_feeBps);
        }
        emit FeeChanged(feeBps, _feeBps);
        feeBps = _feeBps;
    }

    function setPool(IStargatePool lp, uint16 poolId, IOracle oracle, uint80 oracleDecimalsMultipler) external onlyOwner {
        pools[lp] = PoolInfo({poolId: poolId, oracle: oracle, oracleDecimalsMultipler: oracleDecimalsMultipler});

        IERC20(address(lp)).safeApprove(address(stargateRouter), type(uint256).max);

        emit PoolChanged(lp, poolId, oracle);
    }

    function getMaximumInstantRedeemable(IStargatePool lp) public view returns (uint256 max) {
        uint256 totalLiquidity = lp.totalLiquidity();

        if (totalLiquidity > 0) {
            uint256 amountSD = lp.deltaCredit();
            max = (amountSD * lp.totalSupply()) / totalLiquidity;
        }
    }

    /// @param dstChainId the chainId to remove liquidity
    /// @param srcPoolId the source poolId
    /// @param dstPoolId the destination poolId
    /// @param amount quantity of LP tokens to redeem
    /// @param txParams adpater parameters
    /// https://layerzero.gitbook.io/docs/technical-reference/mainnet/supported-chain-ids
    function redeemLocal(
        uint16 dstChainId,
        uint256 srcPoolId,
        uint256 dstPoolId,
        uint256 amount,
        IStargateRouter.lzTxObj memory txParams
    ) external payable onlyAllowedExecutors {
        stargateRouter.redeemLocal{value: msg.value}(
            dstChainId,
            srcPoolId,
            dstPoolId,
            payable(msg.sender),
            amount,
            abi.encodePacked(address(this)),
            txParams
        );
    }

    function instantRedeemLocalMax(IStargatePool lp) external onlyAllowedExecutors {
        PoolInfo memory info = pools[lp];

        uint256 amount = IERC20(address(lp)).balanceOf(address(this));
        uint256 max = getMaximumInstantRedeemable(lp);

        stargateRouter.instantRedeemLocal(info.poolId, amount > max ? max : amount, address(this));
    }

    function instantRedeemLocal(IStargatePool lp, uint256 amount) external onlyAllowedExecutors {
        PoolInfo memory info = pools[lp];
        stargateRouter.instantRedeemLocal(info.poolId, amount, address(this));
    }

    /// @dev Swap internal tokens using an aggregator, for example, 1inch, 0x.
    function swapOnAggregator(address aggreagtorRouter, IERC20 tokenIn, bytes calldata data) external onlyAllowedExecutors {
        tokenIn.safeApprove(aggreagtorRouter, type(uint256).max);

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = aggreagtorRouter.call(data);
        if (!success) {
            revert ErrSwapFailed();
        }

        tokenIn.safeApprove(aggreagtorRouter, 0);
    }

    /*** Emergency Functions ***/
    function execute(address to, uint256 value, bytes calldata data) external onlyOwner returns (bool, bytes memory) {
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory result) = to.call{value: value}(data);

        return (success, result);
    }

    function rescueTokens(IERC20 token, address to, uint256 amount) external onlyOwner {
        token.safeTransfer(to, amount);
    }
}
