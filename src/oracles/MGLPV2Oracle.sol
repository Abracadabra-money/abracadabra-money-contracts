// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {IOracle} from "/interfaces/IOracle.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {Owned} from "@solmate/auth/Owned.sol";

interface IMagicGlpRewardHandlerV2 {
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function claimToken(uint256 index) external view returns (address);
    function claimTokensLength() external view returns (uint256);
    function claimEnabled() external view returns (bool);
}

contract MGLPV2Oracle is Owned, IOracle {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for address;

    string internal _name;
    string internal _symbol;

    event LogOracleSet(address indexed token, IOracle indexed oracle);
    event LogOracleUnset(address indexed token);

    error ErrBadOracle();
    error ErrBadToken();
    error ErrUnsupportedToken();
    error ErrClaimNotEnabled();

    mapping(address => IOracle) public oracles;
    IMagicGlpRewardHandlerV2 public magicGlp;

    constructor(string memory name_, string memory symbol_, IMagicGlpRewardHandlerV2 magicGlp_) Owned(msg.sender) {
        _name = name_;
        _symbol = symbol_;
        magicGlp = magicGlp_;
    }

    function setOracle(address _token, IOracle _oracle) external onlyOwner {
        require(address(_token) != address(0), ErrBadToken());
        require(address(_oracle) != address(0), ErrBadOracle());
        oracles[_token] = _oracle;
        emit LogOracleSet(_token, _oracle);
    }

    function unsetOracle(address _token) external onlyOwner {
        require(address(_token) != address(0), ErrBadToken());
        require(address(oracles[_token]) != address(0), ErrBadToken());
        oracles[_token] = IOracle(address(0));
        emit LogOracleUnset(_token);
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    // Get the latest exchange rate
    /// @inheritdoc IOracle
    function get(bytes calldata data) public override returns (bool, uint256) {
        require(magicGlp.claimEnabled(), ErrClaimNotEnabled());
        uint256 length = magicGlp.claimTokensLength();
        uint256 tvl = 0;
        bool success = true;
        for (uint256 i = 0; i < length; ++i) {
            address token = magicGlp.claimToken(i);
            IOracle oracle = oracles[token];
            require(address(oracle) != address(0), ErrUnsupportedToken());
            (bool ok, uint256 price) = oracle.get(data);
            success = success && ok;
            tvl += (10**oracle.decimals() * token.balanceOf(address(magicGlp))).divWad(uint256(price) * 10**(IERC20Metadata(token).decimals()));
        }
        return (success, magicGlp.totalSupply() * 1e36 / (tvl * 10**magicGlp.decimals()));
    }

    // Check the last exchange rate without any state changes
    /// @inheritdoc IOracle
    function peek(bytes calldata data) public view override returns (bool, uint256) {
        require(magicGlp.claimEnabled(), ErrClaimNotEnabled());
        uint256 length = magicGlp.claimTokensLength();
        uint256 tvl = 0;
        bool success = true;
        for (uint256 i = 0; i < length; ++i) {
            address token = magicGlp.claimToken(i);
            IOracle oracle = oracles[token];
            require(address(oracle) != address(0), ErrUnsupportedToken());
            (bool ok, uint256 price) = oracle.peek(data);
            success = success && ok;
            tvl += (10**oracle.decimals() * token.balanceOf(address(magicGlp))).divWad(uint256(price) * 10**(IERC20Metadata(token).decimals()));
        }
        return (success, magicGlp.totalSupply() * 1e36 / (tvl * 10**magicGlp.decimals()));
    }

    // Check the current spot exchange rate without any state changes
    /// @inheritdoc IOracle
    function peekSpot(bytes calldata data) external view override returns (uint256 rate) {
        require(magicGlp.claimEnabled(), ErrClaimNotEnabled());
        uint256 length = magicGlp.claimTokensLength();
        uint256 tvl = 0;
        for (uint256 i = 0; i < length; ++i) {
            address token = magicGlp.claimToken(i);
            IOracle oracle = oracles[token];
            require(address(oracle) != address(0), ErrUnsupportedToken());
            uint256 price = oracle.peekSpot(data);
            tvl += (10**oracle.decimals() * token.balanceOf(address(magicGlp))).divWad(uint256(price) * 10**(IERC20Metadata(token).decimals()));
        }
        return magicGlp.totalSupply() * 1e36 / (tvl * 10**magicGlp.decimals());
    }

    /// @inheritdoc IOracle
    function name(bytes calldata) public view override returns (string memory) {
        return _name;
    }

    /// @inheritdoc IOracle
    function symbol(bytes calldata) public view override returns (string memory) {
        return _symbol;
    }
}
