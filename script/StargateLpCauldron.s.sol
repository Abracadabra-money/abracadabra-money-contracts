// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import "utils/CauldronDeployLib.sol";
import "oracles/ProxyOracle.sol";
import "interfaces/ISwapperV2.sol";
import "interfaces/ILevSwapperV2.sol";
import "interfaces/ICauldronV4.sol";
import "interfaces/IBentoBoxV1.sol";
import "interfaces/IAggregator.sol";
import "strategies/StargateLPStrategy.sol";

contract StargateLpCauldronScript is BaseScript {
    using DeployerFunctions for Deployer;

    IBentoBoxV1 box;
    address safe;
    IStargatePool pool;
    IStargateRouter router;
    IStargateLPStaking staking;
    address rewardToken;
    address exchange;

    function deploy() public returns (StargateLPStrategy strategy) {
        if (block.chainid == ChainId.Kava) {
            return _deployKavaStargateLPUSDT();
        } else {
            revert("Unsupported chain");
        }
    }

    function _deployKavaStargateLPUSDT() private returns (StargateLPStrategy strategy) {
        pool = IStargatePool(toolkit.getAddress(block.chainid, "stargate.usdtPool"));
        router = IStargateRouter(toolkit.getAddress(block.chainid, "stargate.router"));
        staking = IStargateLPStaking(toolkit.getAddress(block.chainid, "stargate.staking"));
        rewardToken = toolkit.getAddress(block.chainid, "wKava");
        safe = toolkit.getAddress(block.chainid, "safe.ops");
        box = IBentoBoxV1(toolkit.getAddress(block.chainid, "degenBox"));
        exchange = toolkit.getAddress(block.chainid, "aggregators.openocean");

        // USDT Pool
        strategy = deployer.deploy_StargateLPStrategy(
            toolkit.prefixWithChainName(block.chainid, "StargateLPStrategy"),
            pool,
            box,
            router,
            staking,
            rewardToken,
            0
        );

        vm.broadcast();
        strategy.setStargateSwapper(exchange);

        // Stargate LP Oracle 0x547fD22A2d2A9e109A78eB88Fc640D166a64d45F
        // pool: 0xAad094F6A75A14417d39f04E690fC216f080A41a
        // token aggregator (redstone usdt): 0xc0c3B20Af1A431b9Ab4bfe1f396b12D97392e50f
        /*  
            forge create --rpc-url https://evm.data.kava.chainstacklabs.com \
                --constructor-args 0xAad094F6A75A14417d39f04E690fC216f080A41a 0xc0c3B20Af1A431b9Ab4bfe1f396b12D97392e50f "Abracadabra S*USDT"\
                --private-key $PRIVATE_KEY \
                --verify --verifier blockscout --verifier-url https://kavascan.com/api? \
                --legacy \
                src/oracles/StargateLPOracle.sol:StargateLPOracle

            forge verify-contract --chain-id 2222 --num-of-optimizations 800 --watch \
                --constructor-args $(cast abi-encode "constructor(address,address,string)" "0xAad094F6A75A14417d39f04E690fC216f080A41a" "0xc0c3B20Af1A431b9Ab4bfe1f396b12D97392e50f" "Abracadabra S*USDT") \
                --compiler-version v0.8.20+commit.a1b79de6 0x547fD22A2d2A9e109A78eB88Fc640D166a64d45F src/oracles/StargateLPOracle.sol:StargateLPOracle \
                --verifier blockscout --verifier-url https://kavascan.com/api?
        */

        // ProxyOracle 0x70c87439e70EC656A9aE8168B8ED8a194622d026
        /*
            forge create --rpc-url https://evm.data.kava.chainstacklabs.com \
                --private-key $PRIVATE_KEY \
                --verify --verifier blockscout --verifier-url https://kavascan.com/api? \
                --legacy \
                src/oracles/ProxyOracle.sol:ProxyOracle
            
            forge verify-contract --chain-id 2222 --num-of-optimizations 800 --watch \
                --compiler-version v0.8.20+commit.a1b79de6 0x70c87439e70EC656A9aE8168B8ED8a194622d026 src/oracles/ProxyOracle.sol:ProxyOracle \
                --verifier blockscout --verifier-url https://kavascan.com/api?
        */

        // Swapper: 0xF4EfF93BC468cb31F6B838BC0fB171B0A00B1417
        /*
            forge create --rpc-url https://evm.data.kava.chainstacklabs.com \
                --constructor-args 0x630FC1758De85C566Bdec1D75A894794E1819d7E 0xAad094F6A75A14417d39f04E690fC216f080A41a 2 0x2F6F07CDcf3588944Bf4C42aC74ff24bF56e7590 0x471EE749bA270eb4c1165B5AD95E614947f6fCeb 0x6352a56caadC4F1E25CD6c75970Fa768A3304e64 \
                --private-key $PRIVATE_KEY \
                --verify --verifier blockscout --verifier-url https://kavascan.com/api? \
                --legacy \
                src/swappers/StargateLPSwapper.sol:StargateLPSwapper
            
            forge verify-contract --chain-id 2222 --num-of-optimizations 800 --watch \
                --constructor-args $(cast abi-encode "constructor(address,address,uint16,address,address,address)" "0x630FC1758De85C566Bdec1D75A894794E1819d7E" "0xAad094F6A75A14417d39f04E690fC216f080A41a" 2 "0x2F6F07CDcf3588944Bf4C42aC74ff24bF56e7590" "0x471EE749bA270eb4c1165B5AD95E614947f6fCeb" "0x6352a56caadC4F1E25CD6c75970Fa768A3304e64") \
                --compiler-version v0.8.20+commit.a1b79de6 0xF4EfF93BC468cb31F6B838BC0fB171B0A00B1417 src/swappers/StargateLPSwapper.sol:StargateLPSwapper \
                --verifier blockscout --verifier-url https://kavascan.com/api?
        */

        // LevSwapper: 0xaB3274Cfa8f5586C553744AFe1ddA13d97b7fd6f
        /*
            forge create --rpc-url https://evm.data.kava.chainstacklabs.com \
                --constructor-args 0x630FC1758De85C566Bdec1D75A894794E1819d7E 0xAad094F6A75A14417d39f04E690fC216f080A41a 2 0x2F6F07CDcf3588944Bf4C42aC74ff24bF56e7590 0x471EE749bA270eb4c1165B5AD95E614947f6fCeb 0x6352a56caadC4F1E25CD6c75970Fa768A3304e64 \
                --private-key $PRIVATE_KEY \
                --verify --verifier blockscout --verifier-url https://kavascan.com/api? \
                --legacy \
                src/swappers/StargateLPLevSwapper.sol:StargateLPLevSwapper
            
            forge verify-contract --chain-id 2222 --num-of-optimizations 800 --watch \
                --constructor-args $(cast abi-encode "constructor(address,address,uint16,address,address,address)" "0x630FC1758De85C566Bdec1D75A894794E1819d7E" "0xAad094F6A75A14417d39f04E690fC216f080A41a" 2 "0x2F6F07CDcf3588944Bf4C42aC74ff24bF56e7590" "0x471EE749bA270eb4c1165B5AD95E614947f6fCeb" "0x6352a56caadC4F1E25CD6c75970Fa768A3304e64") \
                --compiler-version v0.8.20+commit.a1b79de6 0xaB3274Cfa8f5586C553744AFe1ddA13d97b7fd6f src/swappers/StargateLPLevSwapper.sol:StargateLPLevSwapper \
                --verifier blockscout --verifier-url https://kavascan.com/api?
        */

        /*
            cast send --rpc-url https://evm.data.kava.chainstacklabs.com \
                --private-key $PRIVATE_KEY \
                --legacy \
                0x630FC1758De85C566Bdec1D75A894794E1819d7E \
                "deploy(address,bytes,bool)" \
                0x60bbeFE16DC584f9AF10138Da1dfbB4CDf25A097 0x000000000000000000000000aad094f6a75a14417d39f04e690fc216f080a41a00000000000000000000000070c87439e70ec656a9ae8168b8ed8a194622d02600000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000038a9a7ca00000000000000000000000000000000000000000000000000000000000188940000000000000000000000000000000000000000000000000000000000017ae800000000000000000000000000000000000000000000000000000000000000960000000000000000000000000000000000000000000000000000000000000000 true

            CauldronDeployLib.deployCauldronV4(
                deployer,
                "Kava_Stargate_USDT_Cauldron",
                IBentoBoxV1(0x630FC1758De85C566Bdec1D75A894794E1819d7E),
                0x60bbeFE16DC584f9AF10138Da1dfbB4CDf25A097,
                IERC20(0xAad094F6A75A14417d39f04E690fC216f080A41a),
                IOracle(0x70c87439e70EC656A9aE8168B8ED8a194622d026),
                "",
                9700, // 97% ltv
                300, // 3% interests
                15, // 0.15% opening
                50 // 0.5% liquidation
            );
        */
    }
}
