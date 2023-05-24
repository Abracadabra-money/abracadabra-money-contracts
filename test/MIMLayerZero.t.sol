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

    uint8 public constant PT_SEND = 0;
    uint8 public constant PT_SEND_AND_CALL = 1;
    IAnyswapERC20 private constant ANYMIM_MAINNET = IAnyswapERC20(0xbbc4A8d076F4B1888fec42581B6fc58d242CF2D5);

    uint constant ld2sdRate = 10 ** (18 - 8);

    mapping(uint => LzBaseOFTV2) ofts;
    mapping(uint => IMintableBurnable) minterBurners;
    mapping(uint => uint) forkBlocks;
    mapping(uint => ILzEndpoint) lzEndpoints;
    mapping(uint => address) mimWhale;
    mapping(uint => IERC20) MIMs;
    mapping(uint => uint) forks;
    mapping(uint => uint) chainIdToLzChainId;

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

        chainIdToLzChainId[ChainId.Mainnet] = LayerZeroChainId.Mainnet;
        chainIdToLzChainId[ChainId.BSC] = LayerZeroChainId.BSC;
        chainIdToLzChainId[ChainId.Avalanche] = LayerZeroChainId.Avalanche;
        chainIdToLzChainId[ChainId.Polygon] = LayerZeroChainId.Polygon;
        chainIdToLzChainId[ChainId.Arbitrum] = LayerZeroChainId.Arbitrum;
        chainIdToLzChainId[ChainId.Optimism] = LayerZeroChainId.Optimism;
        chainIdToLzChainId[ChainId.Fantom] = LayerZeroChainId.Fantom;
        chainIdToLzChainId[ChainId.Moonriver] = LayerZeroChainId.Moonriver;

        // Setup forks
        for (uint i = 0; i < chains.length; i++) {
            forks[chains[i]] = fork(chains[i], forkBlocks[chains[i]]);
            super.setUp();

            lzEndpoints[block.chainid] = ILzEndpoint(constants.getAddress("LZendpoint", block.chainid));
            MIMs[block.chainid] = IERC20(constants.getAddress("mim", block.chainid));

            script = new MIMLayerZeroScript();
            script.setTesting(true);

            (proxyOFTV2, indirectOFTV2, minterBurner) = script.deploy();

            if (block.chainid == ChainId.Mainnet) {
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

        _testSendFromChain(fromChainId, toChainId, remoteLzChainId, oft, mim, amount);
    }

    function _testSendFromChain(
        uint fromChainId,
        uint toChainId,
        uint16 remoteLzChainId,
        LzBaseOFTV2 oft,
        IERC20 mim,
        uint amount
    ) private {
        address account = mimWhale[fromChainId];
        vm.selectFork(forks[fromChainId]);
        amount = bound(amount, 1 ether, mim.balanceOf(account));

        pushPrank(account);

        if (fromChainId == ChainId.Mainnet) {
            mim.safeApprove(address(oft), amount);
        }

        bytes memory adapterParams = abi.encodePacked(uint16(1), uint256(200_000));
        bytes32 toAddress = bytes32(bytes20(account));

        (uint fee, ) = oft.estimateSendFee(remoteLzChainId, toAddress, amount, false, adapterParams);

        ILzCommonOFT.LzCallParams memory params = ILzCommonOFT.LzCallParams({
            refundAddress: payable(account),
            zroPaymentAddress: address(0),
            adapterParams: ""
        });

        vm.deal(account, fee);

        console2.log("chainId: %s", block.chainid);
        console2.log("from: %s", account);
        console2.log("remoteLzChainId: %s", remoteLzChainId);
        console2.log("toAddress: %s", vm.toString(toAddress));
        console2.log("amount: %s", amount);

        {
            uint mimBalanceBefore = mim.balanceOf(account);
            uint supplyBefore = mim.totalSupply();

            oft.sendFrom{value: fee}(account, remoteLzChainId, toAddress, amount, params);
            amount = _removeDust(amount);
            assertEq(mim.balanceOf(account), mimBalanceBefore - amount, "mim balance is not correct");

            // On mainnet, the totalSupply shouldn't change as the mim is simply transfered to the proxy oft contract
            if (block.chainid == ChainId.Mainnet) {
                assertEq(mim.totalSupply(), supplyBefore, "mim totalSupply is not correct");
            } else {
                assertEq(mim.totalSupply(), supplyBefore - amount, "mim totalSupply is not correct");
            }
            assertEq(address(account).balance, 0, "eth balance is not correct");
        }
        // simulate lzReceive on the destination chain
        address fromOft = address(oft);
        vm.selectFork(forks[toChainId]);
        oft = ofts[toChainId];

        // simulate lzReceive on the destination chain by the endpoint
        _simulateLzReceive(oft, fromChainId, toChainId, fromOft, _removeDust(amount), account);
    }

    function _simulateLzReceive(
        LzBaseOFTV2 oft,
        uint fromChainId,
        uint toChainId,
        address fromOft,
        uint amount,
        address recipient
    ) private {
        pushPrank(address(lzEndpoints[toChainId]));
        uint mimBalanceBefore = MIMs[toChainId].balanceOf(recipient);
        oft.lzReceive(
            uint16(chainIdToLzChainId[fromChainId]),
            abi.encodePacked(fromOft, address(oft)),
            0,
            abi.encodePacked(PT_SEND, bytes32(bytes20(recipient)), uint64(amount))
        );
        //assertEq(mimBalanceBefore, MIMs[toChainId].balanceOf(recipient) + amount, "mim not receive on recipient");
        popPrank();
    }

    function _bytes32ToBytes(bytes32 _bytes32) public pure returns (bytes memory) {
        bytes memory result = new bytes(32);
        assembly {
            mstore(add(result, 32), _bytes32)
        }
        return result;
    }

    function _removeDust(uint _amount) internal view virtual returns (uint amountAfter) {
        uint dust = _amount % ld2sdRate;
        amountAfter = _amount - dust;
    }
}
