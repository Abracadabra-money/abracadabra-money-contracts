// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {LibString} from "@solady/utils/LibString.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Deployer, DeployerDeployment, Deployer} from "./Deployment.sol";
import {ICauldronV2} from "../src/interfaces/ICauldronV2.sol";

library ChainId {
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
    uint256 internal constant Bera = 80094;
    uint256 internal constant Hyper = 998;
    uint256 internal constant Sei = 1329;
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

enum CauldronStatus {
    Active,
    Deprecated,
    Removed
}

struct CauldronInfo {
    address cauldron;
    CauldronStatus status;
    uint8 version;
    string name;
    uint256 creationBlock;
}

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
    string key;
    string status;
    address value;
    uint8 version;
}

contract JsonConfigDecoder {
    function decodeAddresses(bytes memory jsonContent) external pure returns (JsonAddressEntry[] memory) {
        return abi.decode(jsonContent, (JsonAddressEntry[]));
    }

    function decodeCauldrons(bytes memory jsonContent) external pure returns (JsonCauldronEntry[] memory) {
        return abi.decode(jsonContent, (JsonCauldronEntry[]));
    }
}

//
///////////////////////////////////////////////////////////////

/// @notice Toolkit is a toolchain contract that stores all the addresses of the contracts, cauldrons configurations
/// and other information and functionnalities that is needed for the deployment scripts and testing.
/// It is not meant to be deployed but to be used for chainops.
contract Toolkit {
    using LibString for string;

    Vm constant vm = Vm(address(bytes20(uint160(uint256(keccak256("hevm cheat code"))))));

    mapping(string => address) private addressMap;

    // Cauldron Information
    mapping(uint256 => CauldronInfo[]) private cauldronsPerChain;
    mapping(uint256 => mapping(string => mapping(uint8 => address))) public cauldronAddressMap;
    mapping(uint256 => mapping(address => bool)) private cauldronsPerChainExists;
    mapping(uint256 => uint256) private totalCauldronsPerChain;
    mapping(uint256 => string) private chainIdToName;
    mapping(uint256 => uint16) private chainIdToLzChainId;

    string[] private addressKeys;

    uint[] public chains = [
        0, // default
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
        ChainId.Blast,
        ChainId.Bera,
        ChainId.Hyper,
        ChainId.Sei
    ];

    bool public testing;
    Deployer public deployer;
    JsonConfigDecoder public decoder;
    mapping(uint256 => mapping(address => bool)) public masterContractPerChainMap;
    mapping(uint256 => address[]) public masterContractsPerChain;

    constructor() {
        decoder = new JsonConfigDecoder();

        deployer = new Deployer();
        vm.allowCheatcodes(address(deployer));
        vm.makePersistent(address(deployer));
        vm.label(address(deployer), "forge-deploy:deployer");

        chainIdToName[0] = "Default";
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
        chainIdToName[ChainId.Bera] = "Bera";
        chainIdToName[ChainId.Hyper] = "Hyper";
        chainIdToName[ChainId.Sei] = "Sei";
    
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
            (string memory path, string memory filename) = getConfigFileInfo(chainId);
            string memory json = vm.readFile(path);
            bytes memory jsonContent;

            jsonContent = vm.parseJson(json, ".addresses");
            try decoder.decodeAddresses(jsonContent) returns (JsonAddressEntry[] memory entries) {
                for (uint j = 0; j < entries.length; j++) {
                    JsonAddressEntry memory entry = entries[j];
                    setAddress(chainId, entry.key, entry.value);
                }
            } catch {
                revert(string.concat("Decoding of addresses failed for ", filename));
            }

            jsonContent = vm.parseJson(json, ".cauldrons");
            try decoder.decodeCauldrons(jsonContent) returns (JsonCauldronEntry[] memory entries) {
                for (uint j = 0; j < entries.length; j++) {
                    JsonCauldronEntry memory entry = entries[j];
                    addCauldron(chainId, entry.key, entry.value, entry.version, _parseCauldronStatus(entry.status), entry.creationBlock);
                }
            } catch {
                revert(string.concat("Decoding of cauldrons failed for ", filename));
            }
        }

        vm.label(address(0), "address(0)");
    }

    function getConfigFileInfo(uint256 chainId) public view returns (string memory path, string memory filename) {
        filename = string.concat(chainIdToName[chainId].lower(), ".json");
        path = string.concat(vm.projectRoot(), "/config/", filename);
    }

    function setAddress(uint256 chainid, string memory key, address value) public {
        if (chainid != 0) {
            key = string.concat(chainIdToName[chainid].lower(), ".", key);
        }

        require(addressMap[key] == address(0), string.concat("address already exists: ", key));
        addressMap[key] = value;
        addressKeys.push(key);

        setLabel(value, key);
    }

    function addCauldron(
        uint256 chainid,
        string memory name,
        address cauldron,
        uint8 version,
        CauldronStatus status,
        uint256 creationBlock
    ) public {
        require(!cauldronsPerChainExists[chainid][cauldron], string.concat("cauldron already added: ", vm.toString(cauldron)));
        CauldronInfo memory cauldronInfo = CauldronInfo(cauldron, status, version, name, creationBlock);

        cauldronsPerChainExists[chainid][cauldron] = true;
        cauldronAddressMap[chainid][name][version] = cauldron;
        cauldronsPerChain[chainid].push(cauldronInfo);

        totalCauldronsPerChain[chainid]++;

        if (status == CauldronStatus.Deprecated) {
            setLabel(cauldron, string.concat(chainIdToName[chainid].lower(), ".cauldron.deprecated.", name));
        } else {
            setLabel(cauldron, string.concat(chainIdToName[chainid].lower(), ".cauldron.", name));
        }
    }

    function getCauldrons(uint256 chainid) public view returns (CauldronInfo[] memory cauldrons) {
        uint256 len = totalCauldronsPerChain[chainid];
        CauldronInfo[] memory cauldronInfos = cauldronsPerChain[chainid];
        cauldrons = new CauldronInfo[](len);

        uint256 index = 0;
        for (uint256 i = 0; i < cauldronInfos.length; i++) {
            CauldronInfo memory info = cauldronInfos[i];
            cauldrons[index] = info;
            index++;
        }
    }

    function getCauldrons(
        uint256 chainid,
        // (address cauldron, CauldronStatus status, uint8 version, string memory name, uint256 creationBlock)
        function(address, CauldronStatus, uint8, string memory, uint256) external view returns (bool) predicate
    ) public view returns (CauldronInfo[] memory filteredCauldronInfos) {
        CauldronInfo[] memory cauldronInfos = getCauldrons(chainid);

        uint256 len = 0;

        // remove based on the predicate
        for (uint256 i = 0; i < cauldronInfos.length; i++) {
            CauldronInfo memory info = cauldronInfos[i];

            if (!predicate(info.cauldron, info.status, info.version, info.name, info.creationBlock)) {
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
        // search for current block.chainid format
        string memory localKey = string.concat(chainIdToName[block.chainid].lower(), ".", key);
        if (addressMap[localKey] != address(0)) {
            return addressMap[localKey];
        }

        // search for explicit <chain_name>.key format first
        if (addressMap[key] != address(0)) {
            return addressMap[key];
        }

        revert(string.concat("address not found: ", key));
    }

    function getAddress(uint256 chainid, string memory key) public view returns (address) {
        if (chainid == 0) {
            revert("invalid chainid");
        }

        key = string.concat(chainIdToName[chainid].lower(), ".", key);

        if (addressMap[key] != address(0)) {
            return addressMap[key];
        }

        revert(string.concat("address not found: ", key));
    }

    function getChainName(uint256 chainid) public view returns (string memory) {
        return chainIdToName[chainid];
    }

    function getLzChainId(uint256 chainid) public view returns (uint16 lzChainId) {
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

    function getOrLoadMasterContracts(uint256 chainid) public returns (address[] memory) {
        if (masterContractsPerChain[chainid].length > 0) {
            return masterContractsPerChain[chainid];
        }

        CauldronInfo[] memory cauldronInfos = getCauldrons(chainid);

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
        if (value == 0) {
            return "0";
        }

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

    function setLabel(address addr, string memory key) public {
        string memory existingLabel = vm.getLabel(addr);

        // Concatenate with the current label
        if (keccak256(abi.encodePacked(existingLabel)) != keccak256(abi.encodePacked(string.concat("unlabeled:", vm.toString(addr))))) {
            vm.label(addr, string.concat(existingLabel, "|", key));
        } else {
            vm.label(addr, key);
        }
    }

    function _parseCauldronStatus(string memory status) private pure returns (CauldronStatus) {
        if (LibString.eq(status, "active")) {
            return CauldronStatus.Active;
        } else if (LibString.eq(status, "deprecated")) {
            return CauldronStatus.Deprecated;
        } else if (LibString.eq(status, "removed")) {
            return CauldronStatus.Removed;
        }

        revert(string.concat("invalid cauldron status: ", status));
    }
}

function getToolkit() returns (Toolkit toolkit) {
    address location = address(bytes20(uint160(uint256(keccak256("toolkit")))));
    toolkit = Toolkit(location);

    if (location.code.length == 0) {
        Vm vm = Vm(address(bytes20(uint160(uint256(keccak256("hevm cheat code"))))));
        bytes memory creationCode = vm.getCode("Toolkit.sol:Toolkit");
        vm.etch(location, abi.encodePacked(creationCode, ""));
        vm.allowCheatcodes(location);
        bytes memory runtimeBytecode = Address.functionCall(location, "");
        vm.etch(location, runtimeBytecode);
        vm.makePersistent(address(location));
        vm.label(location, "toolkit");
    }
}
