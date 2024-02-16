// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseTest.sol";
import {WETH} from "solady/tokens/WETH.sol";
import {ERC20Mock} from "openzeppelin-contracts/mocks/ERC20Mock.sol";
import {Registry} from "/mimswap/periphery/Registry.sol";
import {MagicLP} from "/mimswap//MagicLP.sol";

contract RegistryTest is BaseTest {
    event LogRegister(MagicLP lp_, address indexed baseToken_, address indexed quoteToken_, address indexed creator_);

    address authorizedRegistrer;
    address registryOwner;
    Registry registry;

    function setUp() public override {
        vm.chainId(ChainId.Blast);
        super.setUp();

        registryOwner = makeAddr("RegistryOwner");
        authorizedRegistrer = makeAddr("AuthorizedRegistrer");

        registry = new Registry(registryOwner);

        vm.prank(registryOwner);
        registry.setOperator(authorizedRegistrer, true);
    }

    function testRegisterLP() public {
        address maintainer = makeAddr("Maintainer");
        address feeRateModel = makeAddr("FeeRateModel");

        ERC20Mock baseToken = new ERC20Mock();
        ERC20Mock quoteToken = new ERC20Mock();

        MagicLP lp = new MagicLP();
        lp.init(maintainer, address(baseToken), address(quoteToken), 0, feeRateModel, 1, 500000000000000);

        vm.expectEmit(true, true, true, true, address(registry));
        emit LogRegister(lp, address(baseToken), address(quoteToken), authorizedRegistrer);
        vm.prank(authorizedRegistrer);
        registry.register(address(lp), authorizedRegistrer);

        assertEq(registry.count(address(baseToken), address(quoteToken)), 1);
        assertEq(address(registry.get(address(baseToken), address(quoteToken), 0)), address(lp));
        assertEq(address(registry.get(address(baseToken), address(quoteToken), 0)), address(lp));
    }
}
