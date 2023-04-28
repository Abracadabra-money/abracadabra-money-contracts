// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "interfaces/IBentoBoxV1.sol";
import "script/ConvexCauldrons.s.sol";

contract ConvexWrapperTestBase is BaseTest {
    address constant MIM_WHALE = 0x5f0DeE98360d8200b20812e174d139A1a633EDd2;
    ISwapperV2 swapper;
    ILevSwapperV2 levSwapper;
    ProxyOracle oracle;
    IBentoBoxV1 box;
    IERC20 mim;
    uint256 expectedOraclePrice;

    function initialize(uint256 _expectedOraclePrice) public {
        forkMainnet(17137647);
        super.setUp();

        box = IBentoBoxV1(constants.getAddress("mainnet.degenBox"));
        mim = IERC20(constants.getAddress("mainnet.mim"));

        expectedOraclePrice = _expectedOraclePrice;
    }

    function afterInitialize() public {}

    function testLevSwapper() public {
        pushPrank(MIM_WHALE);
        popPrank();
    }

    function testSwapper() public {
        // deposit mim to the leverage swapper
        pushPrank(MIM_WHALE);
        popPrank();
    }
}

contract TriCryptoConvextWrapperTest is ConvexWrapperTestBase {
    function setUp() public override {
        super.initialize(921051199533511162 /* expected oracle price */);
        ConvexCauldronsScript script = new ConvexCauldronsScript();
        script.setTesting(true);
        (oracle, swapper, levSwapper) = script.deployTricrypto();

        super.afterInitialize();
    }
}

contract Mim3PoolConvextWrapperTest is ConvexWrapperTestBase {
    function setUp() public override {
        super.initialize(921051199533511162 /* expected oracle price */);
        ConvexCauldronsScript script = new ConvexCauldronsScript();
        script.setTesting(true);
        (oracle, swapper, levSwapper) = script.deployTricrypto();

        super.afterInitialize();
    }
}