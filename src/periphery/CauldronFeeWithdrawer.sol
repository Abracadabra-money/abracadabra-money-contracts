// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/BoringOwnable.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import "BoringSolidity/ERC20.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/IAnyswapRouter.sol";
import "interfaces/ICauldronV1.sol";
import "interfaces/ICauldronV2.sol";

contract CauldronFeeWithdrawer is BoringOwnable {
    using BoringERC20 for IERC20;

    event SwappedMimToSpell(uint256 amountSushiswap, uint256 amountUniswap, uint256 total);

    event LogOperatorChanged(address indexed operator, bool previous, bool current);
    event LogSwappingRecipientChanged(address indexed recipient, bool previous, bool current);
    event LogTreasuryParametersChanged(address indexed previous, address indexed current, uint256 previousShare, uint256 currentShare);
    event LogSwapperChanged(address indexed previous, address indexed current);
    event LogMimProviderChanged(address indexed previous, address indexed current);
    event LogMimWithdrawn(IBentoBoxV1 indexed bentoBox, uint256 amount);
    event LogMimTotalWithdrawn(uint256 amount);
    event LogSwapMimTransfer(uint256 amounIn, uint256 amountOut, IERC20 tokenOut);
    event LogBentoBoxChanged(IBentoBoxV1 indexed bentoBox, bool previous, bool current);
    event LogCauldronChanged(address indexed cauldron, bool previous, bool current);

    error ErrInsupportedToken(IERC20 tokenOut);
    error ErrNotOperator(address operator);
    error ErrSwapFailed();
    error ErrInvalidFeeTo(address masterContract);
    error ErrInsufficientAmountOut(uint256 amountOut);
    error ErrInvalidSwappingRecipient(address recipient);

    struct CauldronInfo {
        address cauldron;
        address masterContract;
        IBentoBoxV1 bentoBox;
        uint8 version;
    }

    ERC20 public immutable mim;

    uint256 public treasuryShare;
    address public treasury;
    address public swapper;
    address public mimProvider;

    mapping(IERC20 => bool) public swapTokenOutEnabled;
    mapping(address => bool) public operators;
    mapping(address => bool) public swappingRecipients;

    CauldronInfo[] public cauldronInfos;
    IBentoBoxV1[] public bentoBoxes;

    modifier onlyOperators() {
        if (msg.sender != owner && !operators[msg.sender]) {
            revert ErrNotOperator(msg.sender);
        }
        _;
    }

    constructor(
        ERC20 _mim,
        address _treasury,
        uint256 _treasuryShare
    ) {
        mim = _mim;
        treasury = _treasury;
        treasuryShare = _treasuryShare;

        emit LogTreasuryParametersChanged(address(0), _treasury, 0, _treasuryShare);
    }

    function withdraw() external {
        for (uint256 i = 0; i < cauldronInfos.length; i++) {
            CauldronInfo memory info = cauldronInfos[i];

            if (ICauldronV1(info.masterContract).feeTo() != address(this)) {
                revert ErrInvalidFeeTo(info.masterContract);
            }

            ICauldronV1(info.cauldron).accrue();
            uint256 feesEarned;
            IBentoBoxV1 bentoBox = info.bentoBox;

            if (info.version == 1) {
                (, feesEarned) = ICauldronV1(info.cauldron).accrueInfo();
            } else if (info.version >= 2) {
                (, feesEarned, ) = ICauldronV2(info.cauldron).accrueInfo();
            }

            if (feesEarned > (bentoBox.toAmount(mim, bentoBox.balanceOf(mim, info.cauldron), false))) {
                mim.transferFrom(mimProvider, address(bentoBox), feesEarned);
                bentoBox.deposit(mim, address(bentoBox), info.cauldron, feesEarned, 0);
            }

            ICauldronV1(info.cauldron).withdrawFees();
        }

        uint256 amount = withdrawAllMimFromBentoBoxes();
        emit LogMimTotalWithdrawn(amount);
    }

    function withdrawAllMimFromBentoBoxes() public returns (uint256 totalAmount) {
        for (uint256 i = 0; i < bentoBoxes.length; i++) {
            uint256 share = bentoBoxes[i].balanceOf(mim, address(this));
            uint256 amount = bentoBoxes[i].toAmount(mim, share, false);

            totalAmount += amount;
            bentoBoxes[i].withdraw(mim, address(this), address(this), 0, share);

            emit LogMimWithdrawn(bentoBoxes[i], amount);
        }
    }

    function withdrawMimFromBentoBoxes(uint256[] memory shares) public returns (uint256 totalAmount) {
        for (uint256 i = 0; i < bentoBoxes.length; i++) {
            uint256 share = shares[i];
            uint256 amount = bentoBoxes[i].toAmount(mim, share, false);

            totalAmount += amount;
            bentoBoxes[i].withdraw(mim, address(this), address(this), 0, share);

            emit LogMimWithdrawn(bentoBoxes[i], amount);
        }
    }

    function setTreasuryShare(uint256 share) external onlyOwner {
        treasuryShare = share;
    }

    function swapMimAndTransfer(
        uint256 amountOutMin,
        IERC20 tokenOut,
        address recipient,
        bytes calldata data
    ) external onlyOperators {
        if (!swapTokenOutEnabled[tokenOut]) {
            revert ErrInsupportedToken(tokenOut);
        }
        if (!swappingRecipients[recipient]) {
            revert ErrInvalidSwappingRecipient(recipient);
        }

        uint256 amountInBefore = mim.balanceOf(address(this));
        uint256 amountOutBefore = tokenOut.balanceOf(address(this));

        (bool success, ) = swapper.call(data);
        if (!success) {
            revert ErrSwapFailed();
        }

        uint256 amountOut = tokenOut.balanceOf(address(this)) - amountOutBefore;
        if (amountOut < amountOutMin) {
            revert ErrInsufficientAmountOut(amountOut);
        }

        uint256 amountIn = amountInBefore - mim.balanceOf(address(this));
        tokenOut.safeTransfer(recipient, amountOut);

        emit LogSwapMimTransfer(amountIn, amountOut, tokenOut);
    }

    function setCauldron(
        address cauldron,
        uint8 version,
        bool enabled
    ) external onlyOwner {
        _setCauldron(cauldron, version, enabled);
    }

    function setCauldrons(
        address[] memory cauldrons,
        uint8[] memory versions,
        bool[] memory enabled
    ) external onlyOwner {
        for (uint256 i = 0; i < cauldrons.length; i++) {
            _setCauldron(cauldrons[i], versions[i], enabled[i]);
        }
    }

    function _setCauldron(
        address cauldron,
        uint8 version,
        bool enabled
    ) internal onlyOwner {
        bool previousEnabled;

        for (uint256 i = 0; i < cauldronInfos.length; i++) {
            CauldronInfo memory info = cauldronInfos[i];

            if (info.cauldron == cauldron) {
                cauldronInfos[i] = cauldronInfos[cauldronInfos.length - 1];
                cauldronInfos.pop();
                previousEnabled = true;
                break;
            }
        }

        if (enabled) {
            cauldronInfos.push(
                CauldronInfo({
                    cauldron: cauldron,
                    masterContract: address(ICauldronV1(cauldron).masterContract()),
                    bentoBox: IBentoBoxV1(ICauldronV1(cauldron).bentoBox()),
                    version: version
                })
            );
        }

        emit LogCauldronChanged(cauldron, previousEnabled, enabled);
    }

    function setOperator(address operator, bool enabled) external onlyOwner {
        emit LogOperatorChanged(operator, operators[operator], enabled);
        operators[operator] = enabled;
    }

    function setSwappingRecipient(address recipient, bool enabled) external onlyOwner {
        emit LogSwappingRecipientChanged(recipient, swappingRecipients[recipient], enabled);
        swappingRecipients[recipient] = enabled;
    }

    function setTreasuryParameters(address _treasury, uint256 _treasuryShare) external onlyOwner {
        emit LogTreasuryParametersChanged(treasury, _treasury, treasuryShare, _treasuryShare);
        treasury = _treasury;
        treasuryShare = _treasuryShare;
    }

    function setSwapper(address _swapper) external onlyOwner {
        if (swapper != address(0)) {
            mim.approve(swapper, 0);
        }

        mim.approve(_swapper, type(uint256).max);
        emit LogSwapperChanged(swapper, _swapper);

        swapper = _swapper;
    }

    function setMimProvider(address _mimProvider) external onlyOwner {
        emit LogMimProviderChanged(mimProvider, _mimProvider);
        mimProvider = _mimProvider;
    }

    function setBentoBox(IBentoBoxV1 bentoBox, bool enabled) external onlyOwner {
        bool previousEnabled;

        for (uint256 i = 0; i < bentoBoxes.length; i++) {
            if (bentoBoxes[i] == bentoBox) {
                bentoBoxes[i] = bentoBoxes[bentoBoxes.length - 1];
                bentoBoxes.pop();
                previousEnabled = true;
                break;
            }
        }

        if (enabled) {
            bentoBoxes.push(bentoBox);
        }

        emit LogBentoBoxChanged(bentoBox, previousEnabled, enabled);
    }

    function rescueTokens(
        IERC20 token,
        address to,
        uint256 amount
    ) external onlyOwner {
        token.safeTransfer(to, amount);
    }

    /// low level execution for any other future added functions
    function execute(
        address to,
        uint256 value,
        bytes calldata data
    ) external onlyOwner returns (bool success, bytes memory result) {
        // solhint-disable-next-line avoid-low-level-calls
        (success, result) = to.call{value: value}(data);
    }
}
