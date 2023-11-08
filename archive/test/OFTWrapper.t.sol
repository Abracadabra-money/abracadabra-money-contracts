// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/OFTWrapper.s.sol";

contract OFTWrapperTest is BaseTest {
    OFTWrapper public wrapper;
    mapping(uint => uint) forkBlocks;
    mapping(uint => address) mimWhale;
    mapping(uint => uint) forks;
    OFTWrapperScript script;

    uint[] chains = [
        ChainId.Mainnet,
        ChainId.BSC,
        ChainId.Avalanche,
        ChainId.Polygon,
        ChainId.Arbitrum,
        ChainId.Optimism,
        ChainId.Fantom,
        ChainId.Moonriver,
        ChainId.Kava
    ];

    uint[] lzChains = [
        LayerZeroChainId.Mainnet,
        LayerZeroChainId.BSC,
        LayerZeroChainId.Avalanche,
        LayerZeroChainId.Polygon,
        LayerZeroChainId.Arbitrum,
        LayerZeroChainId.Optimism,
        LayerZeroChainId.Fantom,
        LayerZeroChainId.Moonriver,
        LayerZeroChainId.Kava
    ];

    function setUp() public override {
        super.setUp();

        forkBlocks[ChainId.Mainnet] = 17769500;
        forkBlocks[ChainId.BSC] = 30269780;
        forkBlocks[ChainId.Avalanche] = 33057400;
        forkBlocks[ChainId.Polygon] = 45498900;
        forkBlocks[ChainId.Arbitrum] = 114775000;
        forkBlocks[ChainId.Optimism] = 107342000;
        forkBlocks[ChainId.Fantom] = 66282400;
        forkBlocks[ChainId.Moonriver] = 4747750;
        forkBlocks[ChainId.Kava] = 6449609;

        mimWhale[ChainId.Mainnet] = 0x5f0DeE98360d8200b20812e174d139A1a633EDd2;
        mimWhale[ChainId.BSC] = 0x9d9bC38bF4A128530EA45A7d27D0Ccb9C2EbFaf6;
        mimWhale[ChainId.Avalanche] = 0xae64A325027C3C14Cf6abC7818aA3B9c07F5C799;
        mimWhale[ChainId.Polygon] = 0x7d477C61A3db268c31E4350C8613fF0e18A42c06;
        mimWhale[ChainId.Arbitrum] = 0x27807dD7ADF218e1f4d885d54eD51C70eFb9dE50;
        mimWhale[ChainId.Optimism] = 0x4217AA01360846A849d2A89809d450D10248B513;
        mimWhale[ChainId.Fantom] = 0x6f86e65b255c9111109d2D2325ca2dFc82456efc;
        mimWhale[ChainId.Moonriver] = 0x33882266ACC3a7Ab504A95FC694DA26A27e8Bd66;
        mimWhale[ChainId.Kava] = 0xCf5f5ddE4D1D866b11b4cA2ba3Ff146Ec0fe3743;

        // Setup forks
        for (uint i = 0; i < chains.length; i++) {
            console2.log("Forking chain %s", toolkit.getChainName(chains[i]));

            forks[chains[i]] = fork(chains[i], forkBlocks[chains[i]]);
            script = new OFTWrapperScript();
            script.setTesting(true);
            (wrapper) = script.deploy();
        }
    }

    function testSendFrom(uint fromChainId, uint toChainId, uint amount) public {
        fromChainId = chains[fromChainId % chains.length];
        toChainId = toChainId % chains.length;
        uint16 remoteLzChainId = uint16(lzChains[toChainId]);
        toChainId = chains[toChainId % chains.length];

        vm.assume(fromChainId != toChainId);

        _testSendFromChain(fromChainId, remoteLzChainId, amount);
    }

    function _testSendFromChain(uint fromChainId, uint16 remoteLzChainId, uint amount) private {
        vm.selectFork(forks[fromChainId]);
        address account = mimWhale[fromChainId];
        IERC20 mim = IERC20(toolkit.getAddress("mim", block.chainid));
        amount = 1 ether;
        pushPrank(account);
        mim.approve(address(wrapper), amount);

        bytes memory adapterParams = abi.encodePacked(uint16(1), uint256(200_000));
        bytes32 toAddress = bytes32(uint256(uint160(account)));

        (uint fee, ) = wrapper.estimateSendFeeV2(remoteLzChainId, toAddress, amount, adapterParams);

        ILzCommonOFT.LzCallParams memory params = ILzCommonOFT.LzCallParams({
            refundAddress: payable(account),
            zroPaymentAddress: address(0),
            adapterParams: adapterParams
        });

        vm.deal(account, fee);
        {
            uint mimBalanceBefore = mim.balanceOf(account);

            wrapper.sendProxyOFTV2{value: fee}(remoteLzChainId, toAddress, amount, params);
            assertEq(mim.balanceOf(account), mimBalanceBefore - amount, "mim balance is not correct");
            uint balance = address(wrapper).balance;
            address owner = toolkit.getAddress("safe.ops", block.chainid);
            uint256 nativeBalanceBefore = owner.balance;
            wrapper.withdrawFees();
            assertEq(owner.balance, nativeBalanceBefore + balance, "native balance is not correct");
        }
    }
}
