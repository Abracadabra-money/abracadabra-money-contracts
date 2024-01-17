// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20} from "BoringSolidity/interfaces/IERC20.sol";

interface IGmxVault {
    event BuyUSDG(address account, address token, uint256 tokenAmount, uint256 usdgAmount, uint256 feeBasisPoints);
    event ClosePosition(
        bytes32 key,
        uint256 size,
        uint256 collateral,
        uint256 averagePrice,
        uint256 entryFundingRate,
        uint256 reserveAmount,
        int256 realisedPnl
    );
    event CollectMarginFees(address token, uint256 feeUsd, uint256 feeTokens);
    event CollectSwapFees(address token, uint256 feeUsd, uint256 feeTokens);
    event DecreaseGuaranteedUsd(address token, uint256 amount);
    event DecreasePoolAmount(address token, uint256 amount);
    event DecreasePosition(
        bytes32 key,
        address account,
        address collateralToken,
        address indexToken,
        uint256 collateralDelta,
        uint256 sizeDelta,
        bool isLong,
        uint256 price,
        uint256 fee
    );
    event DecreaseReservedAmount(address token, uint256 amount);
    event DecreaseUsdgAmount(address token, uint256 amount);
    event DirectPoolDeposit(address token, uint256 amount);
    event IncreaseGuaranteedUsd(address token, uint256 amount);
    event IncreasePoolAmount(address token, uint256 amount);
    event IncreasePosition(
        bytes32 key,
        address account,
        address collateralToken,
        address indexToken,
        uint256 collateralDelta,
        uint256 sizeDelta,
        bool isLong,
        uint256 price,
        uint256 fee
    );
    event IncreaseReservedAmount(address token, uint256 amount);
    event IncreaseUsdgAmount(address token, uint256 amount);
    event LiquidatePosition(
        bytes32 key,
        address account,
        address collateralToken,
        address indexToken,
        bool isLong,
        uint256 size,
        uint256 collateral,
        uint256 reserveAmount,
        int256 realisedPnl,
        uint256 markPrice
    );
    event SellUSDG(address account, address token, uint256 usdgAmount, uint256 tokenAmount, uint256 feeBasisPoints);
    event Swap(
        address account,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 amountOutAfterFees,
        uint256 feeBasisPoints
    );
    event UpdateFundingRate(address token, uint256 fundingRate);
    event UpdatePnl(bytes32 key, bool hasProfit, uint256 delta);
    event UpdatePosition(
        bytes32 key,
        uint256 size,
        uint256 collateral,
        uint256 averagePrice,
        uint256 entryFundingRate,
        uint256 reserveAmount,
        int256 realisedPnl
    );

    function BASIS_POINTS_DIVISOR() external view returns (uint256);

    function FUNDING_RATE_PRECISION() external view returns (uint256);

    function MAX_FEE_BASIS_POINTS() external view returns (uint256);

    function MAX_FUNDING_RATE_FACTOR() external view returns (uint256);

    function MAX_LIQUIDATION_FEE_USD() external view returns (uint256);

    function MIN_FUNDING_RATE_INTERVAL() external view returns (uint256);

    function MIN_LEVERAGE() external view returns (uint256);

    function PRICE_PRECISION() external view returns (uint256);

    function USDG_DECIMALS() external view returns (uint256);

    function addRouter(address _router) external;

    function adjustForDecimals(uint256 _amount, address _tokenDiv, address _tokenMul) external view returns (uint256);

    function allWhitelistedTokens(uint256) external view returns (address);

    function allWhitelistedTokensLength() external view returns (uint256);

    function approvedRouters(address, address) external view returns (bool);

    function bufferAmounts(address) external view returns (uint256);

    function buyUSDG(address _token, address _receiver) external returns (uint256);

    function clearTokenConfig(address _token) external;

    function cumulativeFundingRates(address) external view returns (uint256);

    function decreasePosition(
        address _account,
        address _collateralToken,
        address _indexToken,
        uint256 _collateralDelta,
        uint256 _sizeDelta,
        bool _isLong,
        address _receiver
    ) external returns (uint256);

    function directPoolDeposit(address _token) external;

    function errorController() external view returns (address);

    function errors(uint256) external view returns (string memory);

    function feeReserves(address) external view returns (uint256);

    function fundingInterval() external view returns (uint256);

    function fundingRateFactor() external view returns (uint256);

    function getDelta(
        address _indexToken,
        uint256 _size,
        uint256 _averagePrice,
        bool _isLong,
        uint256 _lastIncreasedTime
    ) external view returns (bool, uint256);

    function getFeeBasisPoints(
        address _token,
        uint256 _usdgDelta,
        uint256 _feeBasisPoints,
        uint256 _taxBasisPoints,
        bool _increment
    ) external view returns (uint256);

    function getFundingFee(address _token, uint256 _size, uint256 _entryFundingRate) external view returns (uint256);

    function getGlobalShortDelta(address _token) external view returns (bool, uint256);

    function getMaxPrice(address _token) external view returns (uint256);

    function getMinPrice(address _token) external view returns (uint256);

    function getNextAveragePrice(
        address _indexToken,
        uint256 _size,
        uint256 _averagePrice,
        bool _isLong,
        uint256 _nextPrice,
        uint256 _sizeDelta,
        uint256 _lastIncreasedTime
    ) external view returns (uint256);

    function getNextFundingRate(address _token) external view returns (uint256);

    function getNextGlobalShortAveragePrice(address _indexToken, uint256 _nextPrice, uint256 _sizeDelta) external view returns (uint256);

    function getPosition(
        address _account,
        address _collateralToken,
        address _indexToken,
        bool _isLong
    ) external view returns (uint256, uint256, uint256, uint256, uint256, uint256, bool, uint256);

    function getPositionDelta(
        address _account,
        address _collateralToken,
        address _indexToken,
        bool _isLong
    ) external view returns (bool, uint256);

    function getPositionFee(uint256 _sizeDelta) external view returns (uint256);

    function getPositionKey(address _account, address _collateralToken, address _indexToken, bool _isLong) external pure returns (bytes32);

    function getPositionLeverage(
        address _account,
        address _collateralToken,
        address _indexToken,
        bool _isLong
    ) external view returns (uint256);

    function getRedemptionAmount(address _token, uint256 _usdgAmount) external view returns (uint256);

    function getRedemptionCollateral(address _token) external view returns (uint256);

    function getRedemptionCollateralUsd(address _token) external view returns (uint256);

    function getTargetUsdgAmount(address _token) external view returns (uint256);

    function getUtilisation(address _token) external view returns (uint256);

    function globalShortAveragePrices(address) external view returns (uint256);

    function globalShortSizes(address) external view returns (uint256);

    function gov() external view returns (address);

    function guaranteedUsd(address) external view returns (uint256);

    function hasDynamicFees() external view returns (bool);

    function inManagerMode() external view returns (bool);

    function inPrivateLiquidationMode() external view returns (bool);

    function includeAmmPrice() external view returns (bool);

    function increasePosition(address _account, address _collateralToken, address _indexToken, uint256 _sizeDelta, bool _isLong) external;

    function initialize(
        address _router,
        address _usdg,
        address _priceFeed,
        uint256 _liquidationFeeUsd,
        uint256 _fundingRateFactor,
        uint256 _stableFundingRateFactor
    ) external;

    function isInitialized() external view returns (bool);

    function isLeverageEnabled() external view returns (bool);

    function isLiquidator(address) external view returns (bool);

    function isManager(address) external view returns (bool);

    function isSwapEnabled() external view returns (bool);

    function lastFundingTimes(address) external view returns (uint256);

    function liquidatePosition(
        address _account,
        address _collateralToken,
        address _indexToken,
        bool _isLong,
        address _feeReceiver
    ) external;

    function liquidationFeeUsd() external view returns (uint256);

    function marginFeeBasisPoints() external view returns (uint256);

    function maxGasPrice() external view returns (uint256);

    function maxLeverage() external view returns (uint256);

    function maxUsdgAmounts(address) external view returns (uint256);

    function minProfitBasisPoints(address) external view returns (uint256);

    function minProfitTime() external view returns (uint256);

    function mintBurnFeeBasisPoints() external view returns (uint256);

    function poolAmounts(address) external view returns (uint256);

    function positions(
        bytes32
    )
        external
        view
        returns (
            uint256 size,
            uint256 collateral,
            uint256 averagePrice,
            uint256 entryFundingRate,
            uint256 reserveAmount,
            int256 realisedPnl,
            uint256 lastIncreasedTime
        );

    function priceFeed() external view returns (address);

    function removeRouter(address _router) external;

    function reservedAmounts(address) external view returns (uint256);

    function router() external view returns (address);

    function sellUSDG(address _token, address _receiver) external returns (uint256);

    function setBufferAmount(address _token, uint256 _amount) external;

    function setError(uint256 _errorCode, string memory _error) external;

    function setErrorController(address _errorController) external;

    function setFees(
        uint256 _taxBasisPoints,
        uint256 _stableTaxBasisPoints,
        uint256 _mintBurnFeeBasisPoints,
        uint256 _swapFeeBasisPoints,
        uint256 _stableSwapFeeBasisPoints,
        uint256 _marginFeeBasisPoints,
        uint256 _liquidationFeeUsd,
        uint256 _minProfitTime,
        bool _hasDynamicFees
    ) external;

    function setFundingRate(uint256 _fundingInterval, uint256 _fundingRateFactor, uint256 _stableFundingRateFactor) external;

    function setGov(address _gov) external;

    function setInManagerMode(bool _inManagerMode) external;

    function setInPrivateLiquidationMode(bool _inPrivateLiquidationMode) external;

    function setIsLeverageEnabled(bool _isLeverageEnabled) external;

    function setIsSwapEnabled(bool _isSwapEnabled) external;

    function setLiquidator(address _liquidator, bool _isActive) external;

    function setManager(address _manager, bool _isManager) external;

    function setMaxGasPrice(uint256 _maxGasPrice) external;

    function setMaxLeverage(uint256 _maxLeverage) external;

    function setPriceFeed(address _priceFeed) external;

    function setTokenConfig(
        address _token,
        uint256 _tokenDecimals,
        uint256 _tokenWeight,
        uint256 _minProfitBps,
        uint256 _maxUsdgAmount,
        bool _isStable,
        bool _isShortable
    ) external;

    function setUsdgAmount(address _token, uint256 _amount) external;

    function shortableTokens(address) external view returns (bool);

    function stableFundingRateFactor() external view returns (uint256);

    function stableSwapFeeBasisPoints() external view returns (uint256);

    function stableTaxBasisPoints() external view returns (uint256);

    function stableTokens(address) external view returns (bool);

    function swap(address _tokenIn, address _tokenOut, address _receiver) external returns (uint256);

    function swapFeeBasisPoints() external view returns (uint256);

    function taxBasisPoints() external view returns (uint256);

    function tokenBalances(address) external view returns (uint256);

    function tokenDecimals(address) external view returns (uint256);

    function tokenToUsdMin(address _token, uint256 _tokenAmount) external view returns (uint256);

    function tokenWeights(address) external view returns (uint256);

    function totalTokenWeights() external view returns (uint256);

    function updateCumulativeFundingRate(address _token) external;

    function upgradeVault(address _newVault, address _token, uint256 _amount) external;

    function usdToToken(address _token, uint256 _usdAmount, uint256 _price) external view returns (uint256);

    function usdToTokenMax(address _token, uint256 _usdAmount) external view returns (uint256);

    function usdToTokenMin(address _token, uint256 _usdAmount) external view returns (uint256);

    function usdg() external view returns (address);

    function usdgAmounts(address) external view returns (uint256);

    function useSwapPricing() external view returns (bool);

    function validateLiquidation(
        address _account,
        address _collateralToken,
        address _indexToken,
        bool _isLong,
        bool _raise
    ) external view returns (uint256, uint256);

    function whitelistedTokenCount() external view returns (uint256);

    function whitelistedTokens(address) external view returns (bool);

    function withdrawFees(address _token, address _receiver) external returns (uint256);
}

interface IGmxVester {
    function rewardTracker() external view returns (address);

    function claimForAccount(address _account, address _receiver) external returns (uint256);

    function claimable(address _account) external view returns (uint256);

    function setHasMaxVestableAmount(bool _hasMaxVestableAmount) external;

    function cumulativeClaimAmounts(address _account) external view returns (uint256);

    function claimedAmounts(address _account) external view returns (uint256);

    function pairAmounts(address _account) external view returns (uint256);

    function getVestedAmount(address _account) external view returns (uint256);

    function transferredAverageStakedAmounts(address _account) external view returns (uint256);

    function transferredCumulativeRewards(address _account) external view returns (uint256);

    function cumulativeRewardDeductions(address _account) external view returns (uint256);

    function bonusRewards(address _account) external view returns (uint256);

    function transferStakeValues(address _sender, address _receiver) external;

    function setTransferredAverageStakedAmounts(address _account, uint256 _amount) external;

    function setTransferredCumulativeRewards(address _account, uint256 _amount) external;

    function setCumulativeRewardDeductions(address _account, uint256 _amount) external;

    function setBonusRewards(address _account, uint256 _amount) external;

    function getMaxVestableAmount(address _account) external view returns (uint256);

    function getCombinedAverageStakedAmount(address _account) external view returns (uint256);

    function deposit(uint256 _amount) external;

    function withdraw() external;

    function claim() external returns (uint256);

    function getTotalVested(address _account) external view returns (uint256);

    function balances(address account) external view returns (uint256);
}

interface IVaultPriceFeed {
    function adjustmentBasisPoints(address _token) external view returns (uint256);

    function isAdjustmentAdditive(address _token) external view returns (bool);

    function setAdjustment(address _token, bool _isAdditive, uint256 _adjustmentBps) external;

    function setUseV2Pricing(bool _useV2Pricing) external;

    function setIsAmmEnabled(bool _isEnabled) external;

    function setIsSecondaryPriceEnabled(bool _isEnabled) external;

    function setSpreadBasisPoints(address _token, uint256 _spreadBasisPoints) external;

    function setSpreadThresholdBasisPoints(uint256 _spreadThresholdBasisPoints) external;

    function setFavorPrimaryPrice(bool _favorPrimaryPrice) external;

    function setPriceSampleSpace(uint256 _priceSampleSpace) external;

    function setMaxStrictPriceDeviation(uint256 _maxStrictPriceDeviation) external;

    function getPrice(address _token, bool _maximise, bool _includeAmmPrice, bool _useSwapPricing) external view returns (uint256);

    function getAmmPrice(address _token) external view returns (uint256);

    function getPrimaryPrice(address _token, bool _maximise) external view returns (uint256);
}

interface IGmxRewardDistributor {
    function pendingRewards() external view returns (uint256);

    function distribute() external returns (uint256);
}

interface IGmxRewardRouterV2 {
    type VotingPowerType is uint8;

    event StakeGlp(address account, uint256 amount);
    event StakeGmx(address account, address token, uint256 amount);
    event UnstakeGlp(address account, uint256 amount);
    event UnstakeGmx(address account, address token, uint256 amount);

    function BASIS_POINTS_DIVISOR() external view returns (uint256);

    function acceptTransfer(address _sender) external;

    function batchCompoundForAccounts(address[] memory _accounts) external;

    function batchStakeGmxForAccount(address[] memory _accounts, uint256[] memory _amounts) external;

    function bnGmx() external view returns (address);

    function bonusGmxTracker() external view returns (address);

    function claim() external;

    function claimEsGmx() external;

    function claimFees() external;

    function compound() external;

    function compoundForAccount(address _account) external;

    function esGmx() external view returns (address);

    function feeGlpTracker() external view returns (address);

    function feeGmxTracker() external view returns (address);

    function glp() external view returns (address);

    function glpManager() external view returns (address);

    function glpVester() external view returns (address);

    function gmx() external view returns (address);

    function gmxVester() external view returns (address);

    function gov() external view returns (address);

    function govToken() external view returns (address);

    function handleRewards(
        bool shouldClaimGmx,
        bool shouldStakeGmx,
        bool shouldClaimEsGmx,
        bool shouldStakeEsGmx,
        bool shouldStakeMultiplierPoints,
        bool shouldClaimWeth,
        bool shouldConvertWethToEth
    ) external;

    function inStrictTransferMode() external view returns (bool);

    function initialize(
        address _weth,
        address _gmx,
        address _esGmx,
        address _bnGmx,
        address _glp,
        address _stakedGmxTracker,
        address _bonusGmxTracker,
        address _feeGmxTracker,
        address _feeGlpTracker,
        address _stakedGlpTracker,
        address _glpManager,
        address _gmxVester,
        address _glpVester,
        address _govToken
    ) external;

    function isInitialized() external view returns (bool);

    function maxBoostBasisPoints() external view returns (uint256);

    function mintAndStakeGlp(address _token, uint256 _amount, uint256 _minUsdg, uint256 _minGlp) external returns (uint256);

    function mintAndStakeGlpETH(uint256 _minUsdg, uint256 _minGlp) external payable returns (uint256);

    function pendingReceivers(address) external view returns (address);

    function setGov(address _gov) external;

    function setInStrictTransferMode(bool _inStrictTransferMode) external;

    function setMaxBoostBasisPoints(uint256 _maxBoostBasisPoints) external;

    function setVotingPowerType(VotingPowerType _votingPowerType) external;

    function signalTransfer(address _receiver) external;

    function stakeEsGmx(uint256 _amount) external;

    function stakeGmx(uint256 _amount) external;

    function stakeGmxForAccount(address _account, uint256 _amount) external;

    function stakedGlpTracker() external view returns (address);

    function stakedGmxTracker() external view returns (address);

    function unstakeAndRedeemGlp(address _tokenOut, uint256 _glpAmount, uint256 _minOut, address _receiver) external returns (uint256);

    function unstakeAndRedeemGlpETH(uint256 _glpAmount, uint256 _minOut, address payable _receiver) external returns (uint256);

    function unstakeEsGmx(uint256 _amount) external;

    function unstakeGmx(uint256 _amount) external;

    function votingPowerType() external view returns (VotingPowerType);

    function weth() external view returns (address);

    function withdrawToken(address _token, address _account, uint256 _amount) external;
}

interface IGmxRewardTracker {
    function rewardToken() external view returns (address);

    function depositBalances(address _account, address _depositToken) external view returns (uint256);

    function stakedAmounts(address _account) external view returns (uint256);

    function updateRewards() external;

    function stake(address _depositToken, uint256 _amount) external;

    function stakeForAccount(address _fundingAccount, address _account, address _depositToken, uint256 _amount) external;

    function unstake(address _depositToken, uint256 _amount) external;

    function unstakeForAccount(address _account, address _depositToken, uint256 _amount, address _receiver) external;

    function tokensPerInterval() external view returns (uint256);

    function claim(address _receiver) external returns (uint256);

    function claimForAccount(address _account, address _receiver) external returns (uint256);

    function claimable(address _account) external view returns (uint256);

    function averageStakedAmounts(address _account) external view returns (uint256);

    function cumulativeRewards(address _account) external view returns (uint256);
}

interface IGmxStakedGlp {
    function allowance(address _owner, address _spender) external view returns (uint256);

    function allowances(address, address) external view returns (uint256);

    function approve(address _spender, uint256 _amount) external returns (bool);

    function balanceOf(address _account) external view returns (uint256);

    function decimals() external view returns (uint8);

    function feeGlpTracker() external view returns (address);

    function glp() external view returns (address);

    function glpManager() external view returns (address);

    function name() external view returns (string memory);

    function stakedGlpTracker() external view returns (address);

    function symbol() external view returns (string memory);

    function totalSupply() external view returns (uint256);

    function transfer(address _recipient, uint256 _amount) external returns (bool);

    function transferFrom(address _sender, address _recipient, uint256 _amount) external returns (bool);
}

interface IGmxGlpRewardRouter {
    event StakeGlp(address account, uint256 amount);
    event StakeGmx(address account, address token, uint256 amount);
    event UnstakeGlp(address account, uint256 amount);
    event UnstakeGmx(address account, address token, uint256 amount);

    function acceptTransfer(address _sender) external;

    function batchCompoundForAccounts(address[] memory _accounts) external;

    function batchStakeGmxForAccount(address[] memory _accounts, uint256[] memory _amounts) external;

    function claim() external;

    function claimEsGmx() external;

    function claimFees() external;

    function compound() external;

    function compoundForAccount(address _account) external;

    function feeGlpTracker() external view returns (address);

    function glp() external view returns (address);

    function glpManager() external view returns (address);

    function gov() external view returns (address);

    function handleRewards(
        bool shouldClaimGmx,
        bool shouldStakeGmx,
        bool shouldClaimEsGmx,
        bool shouldStakeEsGmx,
        bool shouldStakeMultiplierPoints,
        bool shouldClaimWeth,
        bool shouldConvertWethToEth
    ) external;

    function initialize(
        address _weth,
        address _gmx,
        address _esGmx,
        address _bnGmx,
        address _glp,
        address _stakedGmxTracker,
        address _bonusGmxTracker,
        address _feeGmxTracker,
        address _feeGlpTracker,
        address _stakedGlpTracker,
        address _glpManager,
        address _gmxVester,
        address _glpVester
    ) external;

    function isInitialized() external view returns (bool);

    function mintAndStakeGlp(address _token, uint256 _amount, uint256 _minUsdg, uint256 _minGlp) external returns (uint256);

    function mintAndStakeGlpETH(uint256 _minUsdg, uint256 _minGlp) external payable returns (uint256);

    function pendingReceivers(address) external view returns (address);

    function setGov(address _gov) external;

    function signalTransfer(address _receiver) external;

    function stakeEsGmx(uint256 _amount) external;

    function stakeGmx(uint256 _amount) external;

    function stakeGmxForAccount(address _account, uint256 _amount) external;

    function stakedGlpTracker() external view returns (address);

    function stakedGmxTracker() external view returns (address);

    function unstakeAndRedeemGlp(address _tokenOut, uint256 _glpAmount, uint256 _minOut, address _receiver) external returns (uint256);

    function unstakeAndRedeemGlpETH(uint256 _glpAmount, uint256 _minOut, address _receiver) external returns (uint256);

    function unstakeEsGmx(uint256 _amount) external;

    function unstakeGmx(uint256 _amount) external;

    function withdrawToken(address _token, address _account, uint256 _amount) external;
}

interface IGmxGlpManager {
    event AddLiquidity(
        address account,
        address token,
        uint256 amount,
        uint256 aumInUsdg,
        uint256 glpSupply,
        uint256 usdgAmount,
        uint256 mintAmount
    );
    event RemoveLiquidity(
        address account,
        address token,
        uint256 glpAmount,
        uint256 aumInUsdg,
        uint256 glpSupply,
        uint256 usdgAmount,
        uint256 amountOut
    );

    function BASIS_POINTS_DIVISOR() external view returns (uint256);

    function GLP_PRECISION() external view returns (uint256);

    function MAX_COOLDOWN_DURATION() external view returns (uint256);

    function PRICE_PRECISION() external view returns (uint256);

    function USDG_DECIMALS() external view returns (uint256);

    function addLiquidity(address _token, uint256 _amount, uint256 _minUsdg, uint256 _minGlp) external returns (uint256);

    function addLiquidityForAccount(
        address _fundingAccount,
        address _account,
        address _token,
        uint256 _amount,
        uint256 _minUsdg,
        uint256 _minGlp
    ) external returns (uint256);

    function aumAddition() external view returns (uint256);

    function aumDeduction() external view returns (uint256);

    function cooldownDuration() external view returns (uint256);

    function getAum(bool maximise) external view returns (uint256);

    function getAumInUsdg(bool maximise) external view returns (uint256);

    function getAums() external view returns (uint256[] memory);

    function getGlobalShortAveragePrice(address _token) external view returns (uint256);

    function getGlobalShortDelta(address _token, uint256 _price, uint256 _size) external view returns (uint256, bool);

    function getPrice(bool _maximise) external view returns (uint256);

    function glp() external view returns (address);

    function gov() external view returns (address);

    function inPrivateMode() external view returns (bool);

    function isHandler(address) external view returns (bool);

    function lastAddedAt(address) external view returns (uint256);

    function removeLiquidity(address _tokenOut, uint256 _glpAmount, uint256 _minOut, address _receiver) external returns (uint256);

    function removeLiquidityForAccount(
        address _account,
        address _tokenOut,
        uint256 _glpAmount,
        uint256 _minOut,
        address _receiver
    ) external returns (uint256);

    function setAumAdjustment(uint256 _aumAddition, uint256 _aumDeduction) external;

    function setCooldownDuration(uint256 _cooldownDuration) external;

    function setGov(address _gov) external;

    function setHandler(address _handler, bool _isActive) external;

    function setInPrivateMode(bool _inPrivateMode) external;

    function setShortsTracker(address _shortsTracker) external;

    function setShortsTrackerAveragePriceWeight(uint256 _shortsTrackerAveragePriceWeight) external;

    function shortsTracker() external view returns (address);

    function shortsTrackerAveragePriceWeight() external view returns (uint256);

    function usdg() external view returns (address);

    function vault() external view returns (address);
}

interface IGmxGlpRewardHandler {
    function harvest() external;

    function swapRewards(
        uint256 amountOutMin,
        IERC20 rewardToken,
        IERC20 outputToken,
        address recipient,
        bytes calldata data
    ) external returns (uint256 amountOut);

    function setFeeParameters(address _feeCollector, uint8 _feePercent) external;

    function setRewardTokenEnabled(IERC20 token, bool enabled) external;

    function setSwappingTokenOutEnabled(IERC20 token, bool enabled) external;

    function setAllowedSwappingRecipient(address recipient, bool enabled) external;

    function setRewardRouter(IGmxRewardRouterV2 _rewardRouter) external;

    function setSwapper(address _swapper) external;

    function unstakeGmx(uint256 amount, uint256 amountTransferToFeeCollector) external;

    function unstakeEsGmxAndVest(uint256 amount, uint256 glpVesterDepositAmount, uint256 gmxVesterDepositAmount) external;

    function withdrawFromVesting(bool withdrawFromGlpVester, bool withdrawFromGmxVester, bool stake) external;

    function claimVestedGmx(bool withdrawFromGlpVester, bool withdrawFromGmxVester, bool stake, bool transferToFeeCollecter) external;
}
