// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/MIMLayerZero.s.sol";
import {IERC165} from "openzeppelin-contracts/utils/introspection/IERC165.sol";
import {IERC20, SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {BoringOwnable} from "BoringSolidity/BoringOwnable.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {LzBaseOFTV2} from "tokens/LzBaseOFTV2.sol";
import {ILzOFTReceiverV2, ILzEndpoint, ILzUltraLightNodeV2, ILzOFTV2, ILzCommonOFT} from "interfaces/ILayerZero.sol";
import {IAnyswapERC20} from "interfaces/IAnyswapERC20.sol";
import {IMintableBurnable} from "interfaces/IMintableBurnable.sol";

contract MIMLayerZeroTest_LzReceiverMock is ILzOFTReceiverV2 {
    Vm vm;

    constructor(Vm _vm) {
        vm = _vm;
    }

    bool revertOnReceive;
    bool gasGuzzlingEnabled;

    function setRevertOnReceive(bool _revertOnReceive) external {
        revertOnReceive = _revertOnReceive;
    }

    function enableGasGuzzling(bool _gasGuzzlingEnabled) external {
        gasGuzzlingEnabled = _gasGuzzlingEnabled;
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
        uint gasLeftBefore = gasleft();
        console2.log("onOFTReceived");
        console2.log(" - gasleft before: %s", gasLeftBefore);
        console2.log(" - srcChainId: %s", _srcChainId);
        console2.log(" - srcAddress: %s", vm.toString(_srcAddress));
        console2.log(" - nonce: %s", _nonce);
        console2.log(" - from: %s", vm.toString(_from));
        console2.log(" - amount: %s", _amount);
        console2.log(" - payload: %s", vm.toString(_payload));

        if (gasGuzzlingEnabled) {
            uint x;
            for (uint i = 0; i < 10000; i++) {
                x++;
            }
        }

        if (revertOnReceive) {
            revert("MIMLayerZeroTest_LzReceiverMock: simulated call revert");
        }

        if (_payload.length > 0) {
            (IERC20 mim, bytes memory data) = abi.decode(_payload, (IERC20, bytes));

            (bool success, ) = address(mim).call{value: 0}(data);
            if (!success) {
                revert("MIMLayerZeroTest_LzReceiverMock: payload call failed");
            }
        }

        console2.log(" - gasleft after: %s", gasleft());
    }
}

contract MIMLayerZeroTest is BaseTest {
    using SafeERC20 for IERC20;

    event MessageFailed(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, bytes _payload, bytes _reason);
    event RetryMessageSuccess(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, bytes32 _payloadHash);
    event ReceiveFromChain(uint16 indexed _srcChainId, address indexed _to, uint _amount);
    event CallOFTReceivedSuccess(uint16 indexed _srcChainId, bytes _srcAddress, uint64 _nonce, bytes32 _hash);
    event LogFeeCollected(uint256 amount);

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
    mapping(uint256 => mapping(uint256 => bool)) private openedPaths;

    uint[] chains = [
        ChainId.Mainnet,
        //ChainId.BSC,
        ChainId.Avalanche,
        ChainId.Polygon,
        ChainId.Arbitrum,
        ChainId.Optimism,
        ChainId.Fantom,
        ChainId.Moonriver,
        //ChainId.Kava,
        ChainId.Base,
        ChainId.Linea,
        ChainId.Blast
    ];

    uint[] lzChains = [
        LayerZeroChainId.Mainnet,
        //LayerZeroChainId.BSC,
        LayerZeroChainId.Avalanche,
        LayerZeroChainId.Polygon,
        LayerZeroChainId.Arbitrum,
        LayerZeroChainId.Optimism,
        LayerZeroChainId.Fantom,
        LayerZeroChainId.Moonriver,
        //LayerZeroChainId.Kava,
        LayerZeroChainId.Base,
        LayerZeroChainId.Linea,
        LayerZeroChainId.Blast
    ];

    MIMLayerZeroTest_LzReceiverMock lzReceiverMock;
    uint256 mimAmountOnMainnet;

    ILzFeeHandler feeHandler;
    uint256 nativeBalanceBefore;
    uint256 protocolFee;

    function setUp() public override {
        super.setUp();

        lzReceiverMock = new MIMLayerZeroTest_LzReceiverMock(vm);
        vm.makePersistent(address(lzReceiverMock));

        MIMLayerZeroScript script;
        LzProxyOFTV2 proxyOFTV2;
        LzIndirectOFTV2 indirectOFTV2;
        IMintableBurnable minterBurner;

        mimWhale[ChainId.Mainnet] = 0x5f0DeE98360d8200b20812e174d139A1a633EDd2;
        //mimWhale[ChainId.BSC] = 0x9d9bC38bF4A128530EA45A7d27D0Ccb9C2EbFaf6;
        mimWhale[ChainId.Avalanche] = 0xae64A325027C3C14Cf6abC7818aA3B9c07F5C799;
        mimWhale[ChainId.Polygon] = 0x7d477C61A3db268c31E4350C8613fF0e18A42c06;
        mimWhale[ChainId.Arbitrum] = 0x27807dD7ADF218e1f4d885d54eD51C70eFb9dE50;
        mimWhale[ChainId.Optimism] = 0x4217AA01360846A849d2A89809d450D10248B513;
        mimWhale[ChainId.Fantom] = 0x6f86e65b255c9111109d2D2325ca2dFc82456efc;
        mimWhale[ChainId.Moonriver] = 0x33882266ACC3a7Ab504A95FC694DA26A27e8Bd66;
        //mimWhale[ChainId.Kava] = 0x591199E16E006Dec3eDcf79AE0fCea1Dd0F5b69D;
        mimWhale[ChainId.Base] = address(0);
        mimWhale[ChainId.Linea] = address(0);
        mimWhale[ChainId.Blast] = address(0);

        forkBlocks[ChainId.Mainnet] = 19335594;
        //forkBlocks[ChainId.BSC] = 33122911;
        forkBlocks[ChainId.Avalanche] = 42309833;
        forkBlocks[ChainId.Polygon] = 54111532;
        forkBlocks[ChainId.Arbitrum] = 185790253;
        forkBlocks[ChainId.Optimism] = 116820128;
        forkBlocks[ChainId.Fantom] = 76551985;
        forkBlocks[ChainId.Moonriver] = 6245680;
        //forkBlocks[ChainId.Kava] = 7146804;
        forkBlocks[ChainId.Base] = 11224843;
        forkBlocks[ChainId.Linea] = 2595278;
        forkBlocks[ChainId.Blast] = 214609;

        // Setup forks
        for (uint i = 0; i < chains.length; i++) {
            popAllPranks();
            console2.log("forking chain: %s", vm.toString(chains[i]));
            forks[chains[i]] = fork(chains[i], forkBlocks[chains[i]]);

            lzEndpoints[block.chainid] = ILzEndpoint(toolkit.getAddress("LZendpoint", block.chainid));

            script = new MIMLayerZeroScript();
            script.setTesting(true);

            (proxyOFTV2, indirectOFTV2, minterBurner) = script.deploy();

            if (block.chainid == ChainId.Mainnet) {
                MIMs[block.chainid] = IERC20(toolkit.getAddress("mim", block.chainid));
                ofts[block.chainid] = proxyOFTV2;
            }
            // Chains where MIM is the minterBurner itself
            else if (script.isChainUsingAnyswap(block.chainid)) {
                MIMs[block.chainid] = IERC20(toolkit.getAddress("mim", block.chainid));
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

                if (!Operatable(address(minterBurner)).operators(address(ofts[block.chainid]))) {
                    Operatable(address(minterBurner)).setOperator(address(ofts[block.chainid]), true);
                }

                popPrank();
            } else {
                MIMs[block.chainid] = IERC20(address(minterBurner));
                ofts[block.chainid] = indirectOFTV2;

                if (!Operatable(address(MIMs[block.chainid])).operators(address(ofts[block.chainid]))) {
                    pushPrank(BoringOwnable(address(MIMs[block.chainid])).owner());
                    Operatable(address(MIMs[block.chainid])).setOperator(address(ofts[block.chainid]), true);
                    popPrank();
                }

                // create mim whale if address is 0
                if (mimWhale[block.chainid] == address(0)) {
                    mimWhale[block.chainid] = createUser("mimwhale", address(0x42), 100 ether);
                    pushPrank(BoringOwnable(address(MIMs[block.chainid])).owner());
                    IMintableBurnable(address(MIMs[block.chainid])).mint(mimWhale[block.chainid], 1_000_000 ether);
                }

                popPrank();
            }
        }

        // transfer all mim balance from mainnet anyMIM to the proxy oft contract
        // irl this will be done by bridging, for example, mim safe to mainnet and then transfering
        // the mim to the proxy oft contract
        vm.selectFork(forks[ChainId.Mainnet]);
        pushPrank(address(ANYMIM_MAINNET));
        MIMs[block.chainid].safeTransfer(address(ofts[block.chainid]), MIMs[block.chainid].balanceOf(address(ANYMIM_MAINNET)));
        mimAmountOnMainnet = MIMs[block.chainid].balanceOf(address(ofts[block.chainid]));

        // set trusted remote on all oft
        for (uint i = 0; i < chains.length; i++) {
            vm.selectFork(forks[chains[i]]);

            for (uint j = 0; j < chains.length; j++) {
                if (i == j) {
                    continue;
                }

                // verify open path between chains
                {
                    ILzUltraLightNodeV2 node = ILzUltraLightNodeV2(lzEndpoints[block.chainid].defaultSendLibrary());
                    (, , address relayer, , , ) = node.defaultAppConfig(uint16(toolkit.getLzChainId(chains[j])));

                    openedPaths[chains[i]][chains[j]] = relayer != address(0);

                    if (relayer == address(0)) {
                        console2.log(string.concat("no open path between ", vm.toString(chains[i]), " and ", vm.toString(chains[j])));
                    }
                }

                pushPrank(ofts[chains[i]].owner());

                assertTrue(ofts[chains[i]].supportsInterface(type(ILzOFTV2).interfaceId), "oft does not support ILzOFTV2");
                assertTrue(ofts[chains[i]].supportsInterface(type(IERC165).interfaceId), "oft does not support IERC165");
                assertTrue(ofts[chains[i]].supportsInterface(0x1f7ecdf7), "oft does not support correct interface id");

                ofts[chains[i]].setTrustedRemote(
                    uint16(toolkit.getLzChainId(chains[j])),
                    abi.encodePacked(address(ofts[chains[j]]), address(ofts[chains[i]]))
                );
                ofts[chains[i]].setMinDstGas(uint16(toolkit.getLzChainId(chains[j])), PT_SEND, 200_000);
                ofts[chains[i]].setMinDstGas(uint16(toolkit.getLzChainId(chains[j])), PT_SEND_AND_CALL, 200_000);
                popPrank();
            }
        }
    }

    /// fromChainId and toChainId are fuzzed as indexes but converted to ChainId to save variable space
    /// forge-config: ci.fuzz.runs = 5000
    function testSendFrom(uint fromChainId, uint toChainId, uint amount) public {
        fromChainId = chains[fromChainId % chains.length];
        toChainId = toChainId % chains.length;
        uint16 remoteLzChainId = uint16(lzChains[toChainId]);
        toChainId = chains[toChainId % chains.length];

        if (!openedPaths[fromChainId][toChainId]) {
            return;
        }

        console2.log("testSendFrom", fromChainId, toChainId, amount);

        vm.assume(fromChainId != toChainId);

        IERC20 mim = MIMs[fromChainId];
        assertNotEq(address(mim), address(0), "mim is address(0)");

        LzBaseOFTV2 oft = ofts[fromChainId];
        assertNotEq(address(oft), address(0), "oft is address(0)");

        _testSendFromChain(fromChainId, toChainId, remoteLzChainId, oft, mim, amount);
    }

    function testSimpleFailingLzReceive() public {
        vm.selectFork(forks[ChainId.Arbitrum]);
        LzBaseOFTV2 oft = ofts[ChainId.Arbitrum];
        uint supplyOftBefore = oft.circulatingSupply();

        lzReceiverMock.setRevertOnReceive(true);
        vm.expectEmit(false, false, false, false);
        emit MessageFailed(0, "", 0, "", "MIMLayerZeroTest_LzReceiverMock: simulated call revert");

        pushPrank(address(lzEndpoints[ChainId.Arbitrum]));
        oft.lzReceive(
            uint16(toolkit.getLzChainId(ChainId.Mainnet)),
            abi.encodePacked(address(ofts[ChainId.Mainnet]), address(oft)),
            123,
            abi.encodePacked(
                PT_SEND_AND_CALL,
                bytes32(uint256(uint160(address(lzReceiverMock)))),
                _ld2sd(1 ether),
                bytes32(uint256(uint160(address(alice)))),
                uint64(100000),
                ""
            )
        );

        assertEq(oft.circulatingSupply(), supplyOftBefore, "circulatingSupply should remain unchanged");
    }

    function testSendFromAndCallGasGuzzling() public {
        vm.selectFork(forks[ChainId.Arbitrum]);
        LzBaseOFTV2 oft = ofts[ChainId.Arbitrum];

        uint64 txGas = 172_500;
        uint64 callGas = 100_000;
        lzReceiverMock.enableGasGuzzling(true);

        pushPrank(address(lzEndpoints[ChainId.Arbitrum]));
        vm.expectEmit(false, false, false, false);
        emit MessageFailed(0, "", 0, "", "MIMLayerZeroTest_LzReceiverMock: simulated call revert");

        oft.lzReceive{gas: txGas}(
            uint16(toolkit.getLzChainId(ChainId.Mainnet)),
            abi.encodePacked(address(ofts[ChainId.Mainnet]), address(oft)),
            123,
            abi.encodePacked(
                PT_SEND_AND_CALL,
                bytes32(uint256(uint160(address(lzReceiverMock)))),
                _ld2sd(1 ether),
                bytes32(uint256(uint160(address(alice)))),
                uint64(callGas),
                ""
            )
        );
    }

    function testSimpleSendFromAndCall() public {
        vm.selectFork(forks[ChainId.Base]);
        LzBaseOFTV2 oft = ofts[ChainId.Base];

        uint64 txGas = 100_000;
        uint64 callGas = 100_000;

        pushPrank(address(lzEndpoints[ChainId.Base]));
        vm.expectEmit(false, false, false, false);
        emit ReceiveFromChain(0, address(0), 0);
        vm.expectEmit(false, false, false, false);
        emit CallOFTReceivedSuccess(0, "", 0, 0);

        oft.lzReceive{gas: txGas}(
            uint16(toolkit.getLzChainId(ChainId.Mainnet)),
            abi.encodePacked(address(ofts[ChainId.Mainnet]), address(oft)),
            123,
            abi.encodePacked(
                PT_SEND_AND_CALL,
                bytes32(uint256(uint160(address(lzReceiverMock)))),
                _ld2sd(1 ether),
                bytes32(uint256(uint160(address(alice)))),
                uint64(callGas),
                ""
            )
        );
    }

    /// forge-config: ci.fuzz.runs = 5000
    function testSendFromAndCall(uint fromChainId, uint toChainId, uint amount) public {
        fromChainId = chains[fromChainId % chains.length];
        toChainId = toChainId % chains.length;
        uint16 remoteLzChainId = uint16(lzChains[toChainId]);
        toChainId = chains[toChainId % chains.length];

        if (!openedPaths[fromChainId][toChainId]) {
            return;
        }

        console2.log("testSendFromAndCall", fromChainId, toChainId, amount);
        console2.log("remove lz chainid: ", remoteLzChainId);
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

        amount = bound(amount, 0, mim.balanceOf(account));
        if (amount > mimAmountOnMainnet) {
            amount = mimAmountOnMainnet;
        }
        pushPrank(account);

        if (fromChainId == ChainId.Mainnet) {
            mim.safeApprove(address(oft), amount);
        }

        bytes memory adapterParams = abi.encodePacked(uint16(1), uint256(200_000));
        bytes32 toAddress = bytes32(uint256(uint160(account)));

        feeHandler = _tryGetFeeHandler(oft);
        nativeBalanceBefore;
        protocolFee;

        if (address(feeHandler) != address(0)) {
            nativeBalanceBefore = address(feeHandler).balance;
            protocolFee = feeHandler.getFee();
        }

        (uint fee, ) = oft.estimateSendFee(remoteLzChainId, toAddress, amount, false, adapterParams);

        ILzCommonOFT.LzCallParams memory params = ILzCommonOFT.LzCallParams({
            refundAddress: payable(account),
            zroPaymentAddress: address(0),
            adapterParams: adapterParams
        });

        vm.deal(account, fee);
        {
            uint mimBalanceBefore = mim.balanceOf(account);
            uint supplyBefore = mim.totalSupply();

            if (address(feeHandler) != address(0)) {
                vm.expectEmit(true, false, false, false);
                emit LogFeeCollected(protocolFee);
                oft.sendFrom{value: fee}(account, remoteLzChainId, toAddress, amount, params);
                assertEq(address(feeHandler).balance, nativeBalanceBefore + protocolFee, "feeHandler balance is not correct");
            } else {
                oft.sendFrom{value: fee}(account, remoteLzChainId, toAddress, amount, params);
            }

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

    function _tryGetFeeHandler(LzBaseOFTV2 oft) private view returns (ILzFeeHandler) {
        try oft.feeHandler() returns (ILzFeeHandler handler) {
            return handler;
        } catch {
            return ILzFeeHandler(address(0));
        }
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
            uint16(toolkit.getLzChainId(fromChainId)),
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
        amount = bound(amount, 0, mim.balanceOf(account));
        if (amount > mimAmountOnMainnet) {
            amount = mimAmountOnMainnet;
        }
        bytes memory payload = abi.encode(
            address(MIMs[toChainId]),
            abi.encodeWithSelector(IERC20.transfer.selector, alice, _removeDust(amount))
        );

        pushPrank(account);

        if (fromChainId == ChainId.Mainnet) {
            mim.safeApprove(address(oft), amount);
        }

        bytes memory adapterParams = abi.encodePacked(uint16(1), uint256(200_000 + 100_000)); // extra 100k gas for the call
        bytes32 toAddress = bytes32(uint256(uint160(account)));

        (uint fee, ) = oft.estimateSendAndCallFee(remoteLzChainId, toAddress, amount, payload, 100_000 /* extra */, false, adapterParams);

        ILzCommonOFT.LzCallParams memory params = ILzCommonOFT.LzCallParams({
            refundAddress: payable(account),
            zroPaymentAddress: address(0),
            adapterParams: adapterParams
        });

        vm.deal(account, fee);
        {
            oft.sendAndCall{value: fee}(account, remoteLzChainId, toAddress, amount, payload, 100_000 /* extra */, params);
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
                            uint16(toolkit.getLzChainId(params.fromChainId)),
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
                uint16(toolkit.getLzChainId(params.fromChainId)),
                abi.encodePacked(params.fromOft, address(params.oft)),
                123,
                // (uint8 packetType, address to, uint64 amountSD, bytes32 from, uint64 dstGasForCall, bytes memory payloadForCall)
                abi.encodePacked(
                    PT_SEND_AND_CALL,
                    bytes32(uint256(uint160(params.to))),
                    _ld2sd(params.amount),
                    bytes32(uint256(uint160(params.from))),
                    uint64(100_000),
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
                    uint16(toolkit.getLzChainId(params.fromChainId)),
                    abi.encodePacked(params.fromOft, address(params.oft)),
                    123,
                    abi.encodePacked(
                        PT_SEND_AND_CALL,
                        bytes32(uint256(uint160(params.to))),
                        _ld2sd(params.amount),
                        bytes32(uint256(uint160(params.from))),
                        uint64(100_000),
                        params.payload
                    )
                );
            } else {
                if (params.amount > 0) {
                    assertNotEq(params.oft.circulatingSupply(), supplyOftBefore, "circulatingSupply should be different");
                }
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
