// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "BoringSolidity/ERC20.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import "BoringSolidity/BoringOwnable.sol";
import "utils/BaseTest.sol";
import "script/MIMLayerZero.s.sol";
import "tokens/LzBaseOFTV2.sol";
import "libraries/SafeApprove.sol";
import "interfaces/ILzEndpoint.sol";
import "interfaces/ILzCommonOFT.sol";
import "interfaces/IAnyswapERC20.sol";
import "interfaces/ILzOFTReceiverV2.sol";

contract MIMLayerZeroTest_LzReceiverMock is ILzOFTReceiverV2 {
    Vm vm;

    constructor(Vm _vm) {
        vm = _vm;
    }

    bool revertOnReceive;

    function setRevertOnReceive(bool _revertOnReceive) external {
        revertOnReceive = _revertOnReceive;
    }

    /**
     * @dev Called by the OFT contract when tokens are received from source chain.
     * @param _srcChainId The chain id of the source chain.
     * @param _srcAddress The address of the OFT token contract on the source chain.
     * @param _nonce The nonce of the transaction on the source chain.
     * @param _from The address of the account who calls the sendAndCall() on the source chain.
     * @param _amount The amount of tokens to transfer.
     * @param _payload Additional data with no specified format.
     */
    function onOFTReceived(
        uint16 _srcChainId,
        bytes calldata _srcAddress,
        uint64 _nonce,
        bytes32 _from,
        uint _amount,
        bytes calldata _payload
    ) external {
        console2.log("onOFTReceived");
        console2.log(" - srcChainId: %s", _srcChainId);
        console2.log(" - srcAddress: %s", vm.toString(_srcAddress));
        console2.log(" - nonce: %s", _nonce);
        console2.log(" - from: %s", vm.toString(_from));
        console2.log(" - amount: %s", _amount);
        console2.log(" - payload: %s", vm.toString(_payload));

        if (revertOnReceive) {
            revert("MIMLayerZeroTest_LzReceiverMock: simulated call revert");
        }

        (IERC20 mim, bytes memory data) = abi.decode(_payload, (IERC20, bytes));

        (bool success, ) = address(mim).call{value: 0}(data);
        if (!success) {
            revert("MIMLayerZeroTest_LzReceiverMock: payload call failed");
        }
    }
}

contract MIMLayerZeroTest is BaseTest {
    using BoringERC20 for IERC20;
    using SafeApprove for IERC20;

    event MessageFailed(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, bytes _payload, bytes _reason);
    event RetryMessageSuccess(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, bytes32 _payloadHash);

    uint8 public constant PT_SEND = 0;
    uint8 public constant PT_SEND_AND_CALL = 1;
    IAnyswapERC20 private constant ANYMIM_MAINNET = IAnyswapERC20(0xbbc4A8d076F4B1888fec42581B6fc58d242CF2D5);
    uint constant ld2sdRate = 10 ** (18 - 8);

    // using mappings instead of a single mapping with a struct because it seems like there's issue
    // with this kind of data structure versus vm.selectFork
    mapping(uint => LzBaseOFTV2) ofts;
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

    MIMLayerZeroTest_LzReceiverMock lzReceiverMock;

    function setUp() public override {
        super.setUp();

        lzReceiverMock = new MIMLayerZeroTest_LzReceiverMock(vm);
        vm.makePersistent(address(lzReceiverMock));

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
            popAllPranks();
            forks[chains[i]] = fork(chains[i], forkBlocks[chains[i]]);

            lzEndpoints[block.chainid] = ILzEndpoint(constants.getAddress("LZendpoint", block.chainid));
            MIMs[block.chainid] = IERC20(constants.getAddress("mim", block.chainid));

            script = new MIMLayerZeroScript();
            script.setTesting(true);

            (proxyOFTV2, indirectOFTV2, minterBurner) = script.deploy();

            if (block.chainid == ChainId.Mainnet) {
                ofts[block.chainid] = proxyOFTV2;
            } else {
                ofts[block.chainid] = indirectOFTV2;

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

        // transfer all mim balance from mainnet anyMIM to the proxy oft contract
        // irl this will be done by bridging, for example, mim safe to mainnet and then transfering
        // the mim to the proxy oft contract
        vm.selectFork(forks[ChainId.Mainnet]);
        pushPrank(address(ANYMIM_MAINNET));
        MIMs[block.chainid].safeTransfer(address(ofts[block.chainid]), MIMs[block.chainid].balanceOf(address(ANYMIM_MAINNET)));
    }

    /// fromChainId and toChainId are fuzzed as indexes but converted to ChainId to save variable space
    /// forge-config: ci.fuzz.runs = 5000
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

    /// forge-config: ci.fuzz.runs = 5000
    function testSendFromAndCall(uint fromChainId, uint toChainId, uint amount) public {
        fromChainId = chains[fromChainId % chains.length];
        toChainId = toChainId % chains.length;
        uint16 remoteLzChainId = uint16(lzChains[toChainId]);
        toChainId = chains[toChainId % chains.length];

        vm.assume(fromChainId != toChainId);

        IERC20 mim = MIMs[fromChainId];
        assertNotEq(address(mim), address(0), "mim is address(0)");

        LzBaseOFTV2 oft = ofts[fromChainId];
        assertNotEq(address(oft), address(0), "oft is address(0)");

        _testSendFromChainAndCall(fromChainId, toChainId, remoteLzChainId, oft, mim, amount);
    }

    function _testSendFromChain(
        uint fromChainId,
        uint toChainId,
        uint16 remoteLzChainId,
        LzBaseOFTV2 oft,
        IERC20 mim,
        uint amount
    ) private {
        vm.selectFork(forks[fromChainId]);
        address account = mimWhale[fromChainId];

        amount = bound(amount, 1 ether, mim.balanceOf(account));

        pushPrank(account);

        if (fromChainId == ChainId.Mainnet) {
            mim.safeApprove(address(oft), amount);
        }

        bytes memory adapterParams = abi.encodePacked(uint16(1), uint256(200_000));
        bytes32 toAddress = bytes32(uint256(uint160(account)));

        (uint fee, ) = oft.estimateSendFee(remoteLzChainId, toAddress, amount, false, adapterParams);

        ILzCommonOFT.LzCallParams memory params = ILzCommonOFT.LzCallParams({
            refundAddress: payable(account),
            zroPaymentAddress: address(0),
            adapterParams: ""
        });

        vm.deal(account, fee);
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

        //_checkTotalSupply();
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
        uint supplyOftBefore = oft.circulatingSupply();

        console2.log("chainId: %s", block.chainid);
        console2.log("fromChainId: %s", fromChainId);
        console2.log("toChainId: %s", toChainId);
        console2.log("fromOft: %s", fromOft);
        console2.log("amount: %s", amount);
        console2.log("recipient: %s", recipient);
        console2.log("oft: %s", address(oft));

        if (toChainId == ChainId.Mainnet) {
            console2.log(MIMs[toChainId].balanceOf(address(oft)));
            console2.log(amount);
            assertGe(
                MIMs[toChainId].balanceOf(address(oft)),
                amount,
                "mim balance is not enough on mainnet proxy to covert the transfer in"
            );
        }

        oft.lzReceive(
            uint16(constants.getLzChainId(fromChainId)),
            abi.encodePacked(fromOft, address(oft)),
            0,
            // (uint8 packetType, bytes32 toAddress, uint64 amountSD)
            abi.encodePacked(PT_SEND, bytes32(uint256(uint160(recipient))), _ld2sd(amount))
        );

        // convert to the same decimals as the proxy oft back to mainnet decimals
        assertEq(MIMs[toChainId].balanceOf(recipient), mimBalanceBefore + amount, "mim not receive on recipient");
        assertEq(supplyOftBefore + amount, oft.circulatingSupply(), "circulatingSupply is not correct");
        popPrank();
    }

    function _testSendFromChainAndCall(
        uint fromChainId,
        uint toChainId,
        uint16 remoteLzChainId,
        LzBaseOFTV2 oft,
        IERC20 mim,
        uint amount
    ) private {
        vm.selectFork(forks[fromChainId]);
        address account = mimWhale[fromChainId];
        amount = bound(amount, 1 ether, mim.balanceOf(account));
        bytes memory payload = abi.encode(
            address(MIMs[toChainId]),
            abi.encodeWithSelector(ERC20.transfer.selector, alice, _removeDust(amount))
        );

        pushPrank(account);

        if (fromChainId == ChainId.Mainnet) {
            mim.safeApprove(address(oft), amount);
        }

        bytes memory adapterParams = abi.encodePacked(uint16(1), uint256(200_000));
        bytes32 toAddress = bytes32(uint256(uint160(account)));

        (uint fee, ) = oft.estimateSendAndCallFee(remoteLzChainId, toAddress, amount, payload, false, adapterParams);

        ILzCommonOFT.LzCallParams memory params = ILzCommonOFT.LzCallParams({
            refundAddress: payable(account),
            zroPaymentAddress: address(0),
            adapterParams: ""
        });

        vm.deal(account, fee);
        {
            oft.sendAndCall{value: fee}(account, remoteLzChainId, toAddress, amount, payload, params);
            assertEq(address(account).balance, 0, "eth balance is not correct");
        }

        // simulate lzReceive on the destination chain
        address fromOft = address(oft);
        vm.selectFork(forks[toChainId]);
        oft = ofts[toChainId];

        // simulate lzReceive on the destination chain by the endpoint
        _simulateLzReceiveAndCall(
            SimulateLzReceiveAndCallParams({
                oft: oft,
                fromChainId: fromChainId,
                toChainId: toChainId,
                fromOft: fromOft,
                amount: _removeDust(amount),
                from: account,
                to: address(lzReceiverMock),
                payload: payload,
                simulateFailAndRetry: (amount & 1) == 1 // let's simulate a failure on odd amount
            })
        );

        //_checkTotalSupply();
    }

    struct SimulateLzReceiveAndCallParams {
        LzBaseOFTV2 oft;
        uint fromChainId;
        uint toChainId;
        address fromOft;
        uint amount;
        address from;
        address to;
        bytes payload;
        bool simulateFailAndRetry;
    }

    function _simulateLzReceiveAndCall(SimulateLzReceiveAndCallParams memory params) private {
        pushPrank(address(lzEndpoints[params.toChainId]));
        uint mimBalanceBefore = MIMs[params.toChainId].balanceOf(alice);
        uint supplyOftBefore = params.oft.circulatingSupply();

        console2.log("chainId: %s", block.chainid);
        console2.log("fromChainId: %s", params.fromChainId);
        console2.log("toChainId: %s", params.toChainId);
        console2.log("fromOft: %s", params.fromOft);
        console2.log("amount: %s", params.amount);
        console2.log("from: %s", params.from);
        console2.log("to: %s", params.to);
        console2.log("oft: %s", address(params.oft));

        if (params.toChainId == ChainId.Mainnet) {
            console2.log(MIMs[params.toChainId].balanceOf(address(params.oft)));
            console2.log(params.amount);
            assertGe(
                MIMs[params.toChainId].balanceOf(address(params.oft)),
                params.amount,
                "mim balance is not enough on mainnet proxy to covert the transfer in"
            );
        }

        {
            if (params.simulateFailAndRetry) {
                lzReceiverMock.setRevertOnReceive(true);
                vm.expectEmit(false, false, false, false);
                emit MessageFailed(0, "", 0, "", "MIMLayerZeroTest_LzReceiverMock: simulated call revert");
            } else {
                lzReceiverMock.setRevertOnReceive(false);
                vm.expectCall(
                    address(params.to),
                    abi.encodeCall(
                        lzReceiverMock.onOFTReceived,
                        (
                            uint16(constants.getLzChainId(params.fromChainId)),
                            abi.encodePacked(params.fromOft, address(params.oft)),
                            uint64(123),
                            bytes32(uint256(uint160(params.from))),
                            _sd2ld(_ld2sd(params.amount)),
                            params.payload
                        )
                    )
                );
            }

            params.oft.lzReceive(
                uint16(constants.getLzChainId(params.fromChainId)),
                abi.encodePacked(params.fromOft, address(params.oft)),
                123,
                // (uint8 packetType, address to, uint64 amountSD, bytes32 from, bytes memory payloadForCall)
                abi.encodePacked(
                    PT_SEND_AND_CALL,
                    bytes32(uint256(uint160(params.to))),
                    _ld2sd(params.amount),
                    bytes32(uint256(uint160(params.from))),
                    params.payload
                )
            );

            if (params.simulateFailAndRetry) {
                // in case of failure, the supply shouldn't change
                assertEq(params.oft.circulatingSupply(), supplyOftBefore, "circulatingSupply should remain unchanged");

                lzReceiverMock.setRevertOnReceive(false);

                // test retry
                // function retryMessage(uint16 _srcChainId, bytes calldata _srcAddress, uint64 _nonce, bytes calldata _payload) public payable virtual {
                vm.expectEmit(false, false, false, false);
                emit RetryMessageSuccess(0, "", 123, 0);
                params.oft.retryMessage(
                    uint16(constants.getLzChainId(params.fromChainId)),
                    abi.encodePacked(params.fromOft, address(params.oft)),
                    123,
                    abi.encodePacked(
                        PT_SEND_AND_CALL,
                        bytes32(uint256(uint160(params.to))),
                        _ld2sd(params.amount),
                        bytes32(uint256(uint160(params.from))),
                        params.payload
                    )
                );
            } else {
                assertNotEq(params.oft.circulatingSupply(), supplyOftBefore, "circulatingSupply should be different");
            }

            // convert to the same decimals as the proxy oft back to mainnet decimals
            assertEq(MIMs[params.toChainId].balanceOf(alice), mimBalanceBefore + params.amount, "mim not receive on destination");
            assertEq(supplyOftBefore + params.amount, params.oft.circulatingSupply(), "circulatingSupply is not correct");
        }

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

    function _ld2sd(uint _amount) internal view virtual returns (uint64) {
        uint amountSD = _amount / ld2sdRate;
        require(amountSD <= type(uint64).max, "OFTCore: amountSD overflow");
        return uint64(amountSD);
    }

    function _sd2ld(uint64 _amountSD) internal view virtual returns (uint) {
        return _amountSD * ld2sdRate;
    }

    // Sum all anyMIM total supply on every chains except mainnet and validate that it's equal to the mainnet anyMIM mim balance
    function _checkTotalSupply() private {
        uint totalSupply = 0;
        for (uint i = 0; i < chains.length; i++) {
            if (chains[i] == ChainId.Mainnet) {
                continue;
            }
            vm.selectFork(forks[chains[i]]);
            totalSupply += MIMs[chains[i]].totalSupply();
            //console.log("chainId: %s, totalSupply: %s", chains[i], MIMs[chains[i]].totalSupply());
        }

        vm.selectFork(forks[ChainId.Mainnet]);
        assertEq(totalSupply, MIMs[ChainId.Mainnet].balanceOf(0xbbc4A8d076F4B1888fec42581B6fc58d242CF2D5), "totalSupply is not correct");
    }

    function _printConfigs() private {
        for (uint i = 0; i < chains.length; i++) {
            vm.selectFork(forks[chains[i]]);
            console2.log("chainId: %s", chains[i]);
            console2.log(" - forkBlock: %s", forkBlocks[chains[i]]);
            console2.log(" - lzChainId: %s", lzChains[i]);
            console2.log(" - mimWhale: %s", vm.toString(mimWhale[chains[i]]));
            console2.log(" - fork number %s", forks[chains[i]]);
            console2.log(" - lzEndpoint: %s", vm.toString(address(lzEndpoints[chains[i]])));
            console2.log(" - MIM: %s", vm.toString(address(MIMs[chains[i]])));
            console2.log(" - oft: %s", vm.toString(address(ofts[chains[i]])));
        }
    }
}
