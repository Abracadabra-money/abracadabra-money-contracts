// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseTest.sol";
import {console} from "forge-std/console.sol";
import {Authority} from "solmate/auth/Auth.sol";
import {MagicLP} from "/mimswap/MagicLP.sol";
import {Factory} from "/mimswap/periphery/Factory.sol";
import {Registry} from "/mimswap/periphery/Registry.sol";
import {IFeeRateModel} from "/mimswap/interfaces/IFeeRateModel.sol";
import {FeeRateModel} from "/mimswap/auxiliary/FeeRateModel.sol";
import {ERC20Mock} from "openzeppelin-contracts/mocks/ERC20Mock.sol";
import {WETH} from "solady/tokens/WETH.sol";

contract FactoryTest is BaseTest {
    ERC20Mock baseToken;
    ERC20Mock quoteToken;

    MagicLP lp;

    FeeRateModel maintainerFeeRateModel;
    address registryOwner;
    Registry registry;

    address authorizedCreator;

    address factoryOwner;
    address maintainer;
    Factory factory;

    function setUp() public override {
        vm.chainId(ChainId.Blast);
        super.setUp();

        registryOwner = makeAddr("RegistryOwner");
        maintainer = makeAddr("Maintainer");
        factoryOwner = makeAddr("FactoryOwner");
        authorizedCreator = makeAddr("AuthorizedCreator");

        baseToken = new ERC20Mock();
        quoteToken = new ERC20Mock();

        lp = new MagicLP();
        maintainerFeeRateModel = new FeeRateModel(0, address(0));
        registry = new Registry(registryOwner);
        factory = new Factory(address(lp), maintainer, IFeeRateModel(address(maintainerFeeRateModel)), registry, factoryOwner);

        vm.prank(registryOwner);
        registry.setOperator(address(factory), true);
    }

    function testCreate() public {
        vm.prank(authorizedCreator);
        MagicLP clone = MagicLP(factory.create(address(baseToken), address(quoteToken), 0, 1_000_000, 500000000000000));

        assertEq(clone.balanceOf(alice), 0);
        baseToken.mint(address(clone), 1000 ether);
        quoteToken.mint(address(clone), 1000 ether);
        clone.buyShares(alice);
        assertNotEq(clone.balanceOf(alice), 0);
    }
}
