// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseTest.sol";
import {MGLPV2Oracle, IMagicGlpRewardHandlerV2} from "/oracles/MGLPV2Oracle.sol";
import {FixedPriceOracle} from "/oracles/FixedPriceOracle.sol";
import {IOracle} from "/interfaces/IOracle.sol";
import {ERC20} from "@solady/tokens/ERC20.sol";

contract MockERC20 is ERC20 {
    string internal _name;
    string internal _symbol;
    uint8 internal _decimals;
    bytes32 internal immutable _nameHash;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        _nameHash = keccak256(bytes(name_));
    }

    function _constantNameHash() internal view virtual override returns (bytes32) {
        return _nameHash;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 value) public virtual {
        _mint(to, value);
    }

    function burn(address from, uint256 value) public virtual {
        _burn(from, value);
    }
}

interface IMagicGlpRewardHandlerV2Admin {
    function addClaimToken(address token) external;
    function removeClaimToken(address token) external;
    function enableClaim(bool enable) external;
}

interface IMagicGlp {
    function setRewardHandler(address _rewardHandler) external;
}

contract MGLPV2OracleTest is BaseTest {
    uint256 constant TOTAL_SUPPLY_SLOT = 3;

    MGLPV2Oracle oracle;
    FixedPriceOracle fsGlpOracle;
    FixedPriceOracle gmEthOracle;

    address magicGlp;
    address safeOps;
    MockERC20 fsGlp;
    MockERC20 gmEth;
    address newRewardHandler = 0x6071Ba2D2fe3A4eB5268F1f9dAD0bCC2b3A6a9ab;

    function setUp() public override {
        fork(ChainId.Arbitrum, 363829723);
        super.setUp();

        magicGlp = toolkit.getAddress("magicGlp");
        safeOps = toolkit.getAddress("safe.ops");
        fsGlp = new MockERC20("fsGLP", "fsGLP", 6);
        gmEth = new MockERC20("gmETH", "gmETH", 18);

        vm.startPrank(safeOps);
        IMagicGlp(magicGlp).setRewardHandler(newRewardHandler);
        IMagicGlpRewardHandlerV2Admin(magicGlp).addClaimToken(address(fsGlp));
        IMagicGlpRewardHandlerV2Admin(magicGlp).addClaimToken(address(gmEth));
        IMagicGlpRewardHandlerV2Admin(magicGlp).enableClaim(true);
        vm.stopPrank();

        oracle = new MGLPV2Oracle("Magic GLP V2 Oracle", "MGLPV2", IMagicGlpRewardHandlerV2(magicGlp));

        fsGlpOracle = new FixedPriceOracle("USD/fsGLP", 1e12, 12);
        gmEthOracle = new FixedPriceOracle("USD/gmETH", 1e18, 18);

        oracle.setOracle(address(fsGlp), fsGlpOracle);
        oracle.setOracle(address(gmEth), gmEthOracle);
    }

    function testOracleGetMethod() public {
        fsGlp.mint(address(magicGlp), 0.5e6);
        gmEth.mint(address(magicGlp), 0.5e18);
        vm.store(address(magicGlp), bytes32(TOTAL_SUPPLY_SLOT), bytes32(uint256(1e18)));

        (bool success, uint256 price) = oracle.get("");
        assertTrue(success);
        assertEqDecimal(price, 1e18, 18);
    }
}
