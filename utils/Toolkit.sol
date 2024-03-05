// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {LibString} from "solady/utils/LibString.sol";
import {Deployer, DeployerDeployment, GlobalDeployer} from "forge-deploy/Deployer.sol";
import {DefaultDeployerFunction} from "forge-deploy/DefaultDeployerFunction.sol";
import {ICauldronV2} from "interfaces/ICauldronV2.sol";

library ChainId {
    uint256 internal constant All = 0;
    uint256 internal constant Mainnet = 1;
    uint256 internal constant BSC = 56;
    uint256 internal constant Polygon = 137;
    uint256 internal constant Fantom = 250;
    uint256 internal constant Optimism = 10;
    uint256 internal constant Arbitrum = 42161;
    uint256 internal constant Avalanche = 43114;
    uint256 internal constant Moonriver = 1285;
    uint256 internal constant Kava = 2222;
    uint256 internal constant Linea = 59144;
    uint256 internal constant Base = 8453;
    uint256 internal constant Blast = 81457;
}

/// @dev https://layerzero.gitbook.io/docs/technical-reference/mainnet/supported-chain-ids
library LayerZeroChainId {
    uint16 internal constant Mainnet = 101;
    uint16 internal constant BSC = 102;
    uint16 internal constant Avalanche = 106;
    uint16 internal constant Polygon = 109;
    uint16 internal constant Arbitrum = 110;
    uint16 internal constant Optimism = 111;
    uint16 internal constant Fantom = 112;
    uint16 internal constant Moonriver = 167;
    uint16 internal constant Kava = 177;
    uint16 internal constant Linea = 183;
    uint16 internal constant Base = 184;
    uint16 internal constant Blast = 243;
}

/// @dev https://layerzero.gitbook.io/docs/evm-guides/ua-custom-configuration
library LayerZeroUAConfigType {
    uint256 internal constant CONFIG_TYPE_INBOUND_PROOF_LIBRARY_VERSION = 1;
    uint256 internal constant CONFIG_TYPE_INBOUND_BLOCK_CONFIRMATIONS = 2;
    uint256 internal constant CONFIG_TYPE_RELAYER = 3;
    uint256 internal constant CONFIG_TYPE_OUTBOUND_PROOF_TYPE = 4;
    uint256 internal constant CONFIG_TYPE_OUTBOUND_BLOCK_CONFIRMATIONS = 5;
    uint256 internal constant CONFIG_TYPE_ORACLE = 6;
}

library Block {
    uint256 internal constant Latest = 0;
}

struct CauldronInfo {
    address cauldron;
    bool deprecated;
    uint8 version;
    string name;
    uint256 creationBlock;
}

/// @notice Toolkit is a toolchain contract that stores all the addresses of the contracts, cauldrons configurations
/// and other information and functionnalities that is needed for the deployment scripts and testing.
/// It is not meant to be deployed but to be used for chainops.
contract Toolkit {
    using LibString for string;

    Vm constant vm = Vm(address(bytes20(uint160(uint256(keccak256("hevm cheat code"))))));

    ///////////////////////////////////////////////////////////////
    /// @dev Json structs for reading from the config files
    /// The name must be in alphabetical order as documented here:
    /// https://book.getfoundry.sh/cheatcodes/parse-json
    struct JsonAddressEntry {
        string key;
        address value;
    }

    struct JsonCauldronEntry {
        uint64 creationBlock;
        bool deprecated;
        string key;
        address value;
        uint8 version;
    }

    struct JsonPairCodeHash {
        string key;
        bytes32 value;
    }
    //
    ///////////////////////////////////////////////////////////////

    mapping(string => address) private addressMap;
    mapping(string => bytes32) private pairCodeHash;

    // Cauldron Information
    mapping(uint256 => CauldronInfo[]) private cauldronsPerChain;
    mapping(uint256 => mapping(string => mapping(uint8 => address))) public cauldronAddressMap;
    mapping(uint256 => mapping(address => bool)) private cauldronsPerChainExists;
    mapping(uint256 => uint256) private totalCauldronsPerChain;
    mapping(uint256 => uint256) private deprecatedCauldronsPerChain;
    mapping(uint256 => string) private chainIdToName;
    mapping(uint256 => uint256) private chainIdToLzChainId;

    string[] private addressKeys;

    uint[] public chains = [
        ChainId.All,
        ChainId.Mainnet,
        ChainId.BSC,
        ChainId.Avalanche,
        ChainId.Polygon,
        ChainId.Arbitrum,
        ChainId.Optimism,
        ChainId.Fantom,
        ChainId.Moonriver,
        ChainId.Kava,
        ChainId.Linea,
        ChainId.Base,
        ChainId.Blast
    ];

    bool public testing;
    GlobalDeployer public deployer;
    mapping(uint256 => mapping(address => bool)) public masterContractPerChainMap;
    mapping(uint256 => address[]) public masterContractsPerChain;

    constructor() {
        deployer = new GlobalDeployer();
        vm.allowCheatcodes(address(deployer));
        vm.makePersistent(address(deployer));
        vm.label(address(deployer), "forge-deploy:deployer");
        deployer.init();

        chainIdToName[ChainId.All] = "all";
        chainIdToName[ChainId.Mainnet] = "Mainnet";
        chainIdToName[ChainId.BSC] = "BSC";
        chainIdToName[ChainId.Polygon] = "Polygon";
        chainIdToName[ChainId.Fantom] = "Fantom";
        chainIdToName[ChainId.Optimism] = "Optimism";
        chainIdToName[ChainId.Arbitrum] = "Arbitrum";
        chainIdToName[ChainId.Avalanche] = "Avalanche";
        chainIdToName[ChainId.Moonriver] = "Moonriver";
        chainIdToName[ChainId.Kava] = "Kava";
        chainIdToName[ChainId.Linea] = "Linea";
        chainIdToName[ChainId.Base] = "Base";
        chainIdToName[ChainId.Blast] = "Blast";

        chainIdToLzChainId[ChainId.Mainnet] = LayerZeroChainId.Mainnet;
        chainIdToLzChainId[ChainId.BSC] = LayerZeroChainId.BSC;
        chainIdToLzChainId[ChainId.Avalanche] = LayerZeroChainId.Avalanche;
        chainIdToLzChainId[ChainId.Polygon] = LayerZeroChainId.Polygon;
        chainIdToLzChainId[ChainId.Arbitrum] = LayerZeroChainId.Arbitrum;
        chainIdToLzChainId[ChainId.Optimism] = LayerZeroChainId.Optimism;
        chainIdToLzChainId[ChainId.Fantom] = LayerZeroChainId.Fantom;
        chainIdToLzChainId[ChainId.Moonriver] = LayerZeroChainId.Moonriver;
        chainIdToLzChainId[ChainId.Kava] = LayerZeroChainId.Kava;
        chainIdToLzChainId[ChainId.Linea] = LayerZeroChainId.Linea;
        chainIdToLzChainId[ChainId.Base] = LayerZeroChainId.Base;
        chainIdToLzChainId[ChainId.Blast] = LayerZeroChainId.Blast;

        for (uint i = 0; i < chains.length; i++) {
            uint256 chainId = chains[i];
            string memory path = string.concat(vm.projectRoot(), "/config/", chainIdToName[chainId].lower(), ".json");

            try vm.readFile(path) returns (string memory json) {
                {
                    bytes memory jsonContent = vm.parseJson(json, ".addresses");
                    JsonAddressEntry[] memory entries = abi.decode(jsonContent, (JsonAddressEntry[]));

                    for (uint j = 0; j < entries.length; j++) {
                        JsonAddressEntry memory entry = entries[j];
                        setAddress(chainId, entry.key, entry.value);
                    }
                }
                {
                    bytes memory jsonContent = vm.parseJson(json, ".cauldrons");
                    JsonCauldronEntry[] memory entries = abi.decode(jsonContent, (JsonCauldronEntry[]));

                    for (uint j = 0; j < entries.length; j++) {
                        JsonCauldronEntry memory entry = entries[j];
                        addCauldron(chainId, entry.key, entry.value, entry.version, entry.deprecated, entry.creationBlock);
                    }
                }
                {
                    bytes memory jsonContent = vm.parseJson(json, ".pairCodeHashes");
                    JsonPairCodeHash[] memory entries = abi.decode(jsonContent, (JsonPairCodeHash[]));

                    for (uint j = 0; j < entries.length; j++) {
                        JsonPairCodeHash memory entry = entries[j];
                        pairCodeHash[string.concat(chainIdToName[chainId].lower(), ".", entry.key)] = entry.value;
                    }
                }
            } catch {}
        }
    }

    function setAddress(uint256 chainid, string memory key, address value) public {
        if (chainid != ChainId.All) {
            key = string.concat(chainIdToName[chainid].lower(), ".", key);
        }

        require(addressMap[key] == address(0), string.concat("address already exists: ", key));
        addressMap[key] = value;
        addressKeys.push(key);

        vm.label(value, key);
    }

    function addCauldron(uint256 chainid, string memory name, address value, uint8 version, bool deprecated, uint256 creationBlock) public {
        require(!cauldronsPerChainExists[chainid][value], string.concat("cauldron already added: ", vm.toString(value)));

        CauldronInfo memory cauldronInfo = CauldronInfo({
            deprecated: deprecated,
            cauldron: value,
            version: version,
            name: name,
            creationBlock: creationBlock
        });

        cauldronsPerChainExists[chainid][value] = true;
        cauldronAddressMap[chainid][name][version] = value;
        cauldronsPerChain[chainid].push(cauldronInfo);

        totalCauldronsPerChain[chainid]++;

        if (deprecated) {
            deprecatedCauldronsPerChain[chainid]++;
            vm.label(value, string.concat(chainIdToName[chainid].lower(), ".cauldron.deprecated.", name));
        } else {
            vm.label(value, string.concat(chainIdToName[chainid].lower(), ".cauldron.", name));
        }
    }

    function getCauldrons(uint256 chainid, bool includeDeprecated) public view returns (CauldronInfo[] memory filteredCauldronInfos) {
        uint256 len = totalCauldronsPerChain[chainid];
        if (!includeDeprecated) {
            len -= deprecatedCauldronsPerChain[chainid];
        }

        CauldronInfo[] memory cauldronInfos = cauldronsPerChain[chainid];
        filteredCauldronInfos = new CauldronInfo[](len);

        uint256 index = 0;
        for (uint256 i = 0; i < cauldronInfos.length; i++) {
            CauldronInfo memory info = cauldronInfos[i];

            if (info.deprecated && !includeDeprecated) {
                continue;
            }

            filteredCauldronInfos[index] = info;
            index++;
        }
    }

    function getCauldrons(
        uint256 chainid,
        bool includeDeprecated,
        // (address cauldron, bool deprecated, uint8 version, string memory name, uint256 creationBlock)
        function(address, bool, uint8, string memory, uint256) external view returns (bool) predicate
    ) public view returns (CauldronInfo[] memory filteredCauldronInfos) {
        CauldronInfo[] memory cauldronInfos = getCauldrons(chainid, includeDeprecated);

        uint256 len = 0;

        // remove based on the predicate
        for (uint256 i = 0; i < cauldronInfos.length; i++) {
            CauldronInfo memory info = cauldronInfos[i];

            if (!predicate(info.cauldron, info.deprecated, info.version, info.name, info.creationBlock)) {
                cauldronInfos[i].cauldron = address(0);
                continue;
            }

            len++;
        }

        filteredCauldronInfos = new CauldronInfo[](len);
        uint256 filteredCauldronInfosIndex = 0;
        for (uint256 i = 0; i < cauldronInfos.length; i++) {
            if (cauldronInfos[i].cauldron != address(0)) {
                filteredCauldronInfos[filteredCauldronInfosIndex] = cauldronInfos[i];
                filteredCauldronInfosIndex++;
            }
        }
    }

    function getAddress(string memory key) public view returns (address) {
        require(addressMap[key] != address(0), string.concat("address not found: ", key));
        return addressMap[key];
    }

    function getAddress(string calldata name, uint256 chainid) public view returns (address) {
        if (chainid == ChainId.All) {
            return getAddress(name);
        }
        string memory key = string.concat(chainIdToName[chainid].lower(), ".", name);
        return getAddress(key);
    }

    function getAddress(uint256 chainid, string calldata name) public view returns (address) {
        return getAddress(name, chainid);
    }

    function getPairCodeHash(string calldata key) public view returns (bytes32) {
        require(pairCodeHash[key] != "", string.concat("pairCodeHash not found: ", key));
        return pairCodeHash[key];
    }

    function getChainName(uint256 chainid) public view returns (string memory) {
        return chainIdToName[chainid];
    }

    function getLzChainId(uint256 chainid) public view returns (uint256 lzChainId) {
        lzChainId = chainIdToLzChainId[chainid];
        require(lzChainId != 0, string.concat("layer zero chain id not found from chain id ", vm.toString(chainid)));
    }

    function setTesting(bool _testing) public {
        testing = _testing;
    }

    function prefixWithChainName(uint256 chainid, string memory name) public view returns (string memory) {
        return string.concat(getChainName(chainid), "_", name);
    }

    function getChainsLength() public view returns (uint256) {
        return chains.length;
    }

    function getOrLoadMasterContracts(uint256 chainid, bool includeDeprecated) public returns (address[] memory) {
        if (masterContractsPerChain[chainid].length > 0) {
            return masterContractsPerChain[chainid];
        }

        CauldronInfo[] memory cauldronInfos = getCauldrons(chainid, includeDeprecated);

        for (uint256 i = 0; i < cauldronInfos.length; i++) {
            address masterContract = address(ICauldronV2(cauldronInfos[i].cauldron).masterContract());
            if (!masterContractPerChainMap[chainid][masterContract]) {
                masterContractPerChainMap[chainid][masterContract] = true;
                masterContractsPerChain[chainid].push(masterContract);
            }
        }

        return masterContractsPerChain[chainid];
    }

    function formatDecimals(uint256 value) public pure returns (string memory) {
        return formatDecimals(value, 18);
    }

    function formatDecimals(uint256 value, uint256 decimals) public pure returns (string memory str) {
        uint256 divisor = 10 ** uint256(decimals);
        uint256 integerPart = value / divisor;
        uint256 fractionalPart = value % divisor;

        string memory fractionalPartStr = LibString.toString(fractionalPart);
        bytes memory zeroPadding = new bytes(decimals - bytes(fractionalPartStr).length);

        for (uint256 i = 0; i < zeroPadding.length; i++) {
            zeroPadding[i] = bytes1(uint8(48));
        }

        string memory integerPartStr = "";
        uint128 index;

        while (integerPart > 0) {
            uint256 part = integerPart % 10;
            bool isSet = index != 0 && index % 3 == 0;

            string memory stringified = vm.toString(part);
            string memory glue = ",";

            if (!isSet) glue = "";
            integerPartStr = string(abi.encodePacked(stringified, glue, integerPartStr));

            integerPart = integerPart / 10;
            index += 1;
        }

        return string(abi.encodePacked(integerPartStr, ".", zeroPadding, fractionalPartStr));
    }
}

function getToolkit() returns (Toolkit toolkit) {
    address location = address(bytes20(uint160(uint256(keccak256("toolkit")))));
    toolkit = Toolkit(location);

    if (location.code.length == 0) {
        Vm vm = Vm(address(bytes20(uint160(uint256(keccak256("hevm cheat code"))))));
        bytes memory creationCode = vm.getCode("Toolkit.sol");
        vm.etch(location, abi.encodePacked(creationCode, ""));
        vm.allowCheatcodes(location);
        (bool success, bytes memory runtimeBytecode) = location.call{value: 0}("");
        require(success, "Fail to initialize Toolkit");
        vm.etch(location, runtimeBytecode);
        vm.makePersistent(address(location));
        vm.label(location, "toolkit");
    }
}
