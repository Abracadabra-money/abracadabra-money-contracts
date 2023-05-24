// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "BoringSolidity/libraries/BoringERC20.sol";
import "BoringSolidity/BoringOwnable.sol";
import "utils/BaseTest.sol";
import "script/MIMLayerZero.s.sol";
import "tokens/LzBaseOFTV2.sol";
import "libraries/SafeApprove.sol";
import "interfaces/ILzEndpoint.sol";
import "interfaces/ILzCommonOFT.sol";
import "interfaces/IAnyswapERC20.sol";

contract MIMLayerZeroTest is BaseTest {
    using BoringERC20 for IERC20;
    using SafeApprove for IERC20;

    mapping(uint => LzBaseOFTV2) ofts;
    mapping(uint => IMintableBurnable) minterBurners;
    mapping(uint => uint) forkBlocks;
    mapping(uint => ILzEndpoint) lzEndpoints;
    mapping(uint => address) mimWhale;
    mapping(uint => IERC20) MIMs;
    mapping(uint => uint) forks;

    uint[] chains = [
        ChainId.Mainnet,
        ChainId.BSC,
        ChainId.Avalanche,
        ChainId.Polygon,
        ChainId.Arbitrum,
        ChainId.Optimism,
        ChainId.Fantom,
        ChainId.Moonriver
    ];

    uint[] lzChains = [
        LayerZeroChainId.Mainnet,
        LayerZeroChainId.BSC,
        LayerZeroChainId.Avalanche,
        LayerZeroChainId.Polygon,
        LayerZeroChainId.Arbitrum,
        LayerZeroChainId.Optimism,
        LayerZeroChainId.Fantom,
        LayerZeroChainId.Moonriver
    ];

    function setUp() public override {
        MIMLayerZeroScript script;
        LzProxyOFTV2 proxyOFTV2;
        LzIndirectOFTV2 indirectOFTV2;
        IMintableBurnable minterBurner;

        mimWhale[ChainId.Mainnet] = 0x5f0DeE98360d8200b20812e174d139A1a633EDd2;
        mimWhale[ChainId.BSC] = 0x9d9bC38bF4A128530EA45A7d27D0Ccb9C2EbFaf6;
        mimWhale[ChainId.Avalanche] = 0xae64A325027C3C14Cf6abC7818aA3B9c07F5C799;
        mimWhale[ChainId.Polygon] = 0x7d477C61A3db268c31E4350C8613fF0e18A42c06;
        mimWhale[ChainId.Arbitrum] = 0x27807dD7ADF218e1f4d885d54eD51C70eFb9dE50;
        mimWhale[ChainId.Optimism] = 0x4217AA01360846A849d2A89809d450D10248B513;
        mimWhale[ChainId.Fantom] = 0x6f86e65b255c9111109d2D2325ca2dFc82456efc;
        mimWhale[ChainId.Moonriver] = 0x33882266ACC3a7Ab504A95FC694DA26A27e8Bd66;

        forkBlocks[ChainId.Mainnet] = 17322443;
        forkBlocks[ChainId.BSC] = 28463941;
        forkBlocks[ChainId.Avalanche] = 30393067;
        forkBlocks[ChainId.Polygon] = 43053861;
        forkBlocks[ChainId.Arbitrum] = 93627184;
        forkBlocks[ChainId.Optimism] = 100787201;
        forkBlocks[ChainId.Fantom] = 62910106;
        forkBlocks[ChainId.Moonriver] = 4301842;

        // Setup forks
        for (uint i = 0; i < chains.length; i++) {
            forks[chains[i]] = fork(chains[i], forkBlocks[chains[i]]);
            super.setUp();

            lzEndpoints[block.chainid] = ILzEndpoint(constants.getAddress("LZendpoint", block.chainid));
            MIMs[block.chainid] = IERC20(constants.getAddress("mim", block.chainid));

            script = new MIMLayerZeroScript();
            script.setTesting(true);

            (proxyOFTV2, indirectOFTV2, minterBurner) = script.deploy();

            if (proxyOFTV2 != LzProxyOFTV2(address(0))) {
                ofts[block.chainid] = proxyOFTV2;
            } else {
                ofts[block.chainid] = indirectOFTV2;
                minterBurners[block.chainid] = minterBurner;

                // add minter burner to anyswap-mim
                IAnyswapERC20 anyMim = IAnyswapERC20(address(MIMs[block.chainid]));
                address owner = BoringOwnable(address(anyMim)).owner();
                pushPrank(owner);

                if (!anyMim.isMinter(address(minterBurner))) {
                    anyMim.setMinter(address(minterBurner));
                    advanceTime(anyMim.delayMinter());
                    anyMim.applyMinter();
                    assertTrue(anyMim.isMinter(address(minterBurner)), "minterburner is not a minter");
                }

                // trust remote for avalanche was missing at this block on Polygon
                if (block.chainid == ChainId.Polygon) {
                    ofts[block.chainid].setTrustedRemote(
                        106,
                        hex"225c5e03fc234a9a71c12dc0559d8fd4e460f96f563111a691302d9700abc617e99236d6a6fc537b"
                    );
                }
            }
        }
    }

    // fromChainId and toChainId are fuzzed as indexes but converted to ChainId to save variable space
    function testSendFrom(uint fromChainId, uint toChainId, uint amount) public {
        fromChainId = chains[fromChainId % chains.length];
        toChainId = toChainId % chains.length;
        uint16 remoteLzChainId = uint16(lzChains[toChainId]);
        toChainId = chains[toChainId % chains.length];

        vm.assume(fromChainId != toChainId);

        IERC20 mim = MIMs[fromChainId];
        assertNotEq(address(mim), address(0), "mim is address(0)");

        LzBaseOFTV2 oft = ofts[fromChainId];
        assertNotEq(address(oft), address(0), "oft is address(0)");

        vm.selectFork(forks[fromChainId]);
        amount = bound(amount, 1_000 ether, mim.balanceOf(mimWhale[fromChainId]));

        _testSendFromChain(fromChainId, remoteLzChainId, oft, mim, amount);
    }

    function _testSendFromChain(uint fromChainId, uint16 remoteLzChainId, LzBaseOFTV2 oft, IERC20 mim, uint amount) private {
        pushPrank(mimWhale[fromChainId]);

        if (fromChainId == ChainId.Mainnet) {
            mim.safeApprove(address(oft), amount);
        }

        bytes memory adapterParams = abi.encodePacked(uint16(1), uint256(200_000));
        bytes32 toAddressBytes = bytes32(bytes20(mimWhale[fromChainId]));

        (uint fee, ) = oft.estimateSendFee(remoteLzChainId, toAddressBytes, amount, false, adapterParams);

        ILzCommonOFT.LzCallParams memory params = ILzCommonOFT.LzCallParams({
            refundAddress: payable(mimWhale[fromChainId]),
            zroPaymentAddress: address(0),
            adapterParams: ""
        });
        _simulateLzSend(oft, mimWhale[fromChainId], remoteLzChainId, toAddressBytes, amount, params, fee);
    }

    function _simulateLzSend(
        LzBaseOFTV2 oft,
        address from,
        uint16 remoteLzChainId,
        bytes32 toAddress,
        uint amount,
        ILzCommonOFT.LzCallParams memory params,
        uint fee
    ) private {
        vm.deal(from, fee);

        console2.log("chainId: %s", block.chainid);

        console2.log("from: %s", from);
        console2.log("remoteLzChainId: %s", remoteLzChainId);
        console2.log("toAddress: %s", vm.toString(toAddress));
        console2.log("amount: %s", amount);

        oft.sendFrom{value: fee}(from, remoteLzChainId, toAddress, amount, params);

        assertEq(address(from).balance, 0, "eth balance is not correct");
    }
}
