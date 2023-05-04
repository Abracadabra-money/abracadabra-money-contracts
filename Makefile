-include .env.defaults
-include .env
export

SCRIPT_DIR = ./script
TEST_DIR = ./test
FILES_CONTAINING_CONSOLE := $(shell grep -rlw --max-count=1 --include=\*.sol 'src' -e 'console\.sol')
FILES_CONTAINING_CONSOLE2 := $(shell grep -rlw --max-count=1 --include=\*.sol 'src' -e 'console2\.sol')
ARCHIVE_SCRIPT_FILES = $(wildcard ./archive/script/*.s.sol)
ARCHIVE_TEST_FILES = $(wildcard ./archive/test/*.t.sol)

ifeq (, $(shell which jq))
$(error "jq command not found")
endif
ifeq (, $(shell which cargo))
$(error "cargo command not found. See https://rustup.rs/")
endif
ifeq (, $(shell which nl))
$(error "nl command not found")
endif
ifeq (, $(shell which sed))
$(error "sed command not found")
endif

build:
	make init
	./forge-deploy gen-deployer --templates forge-deploy-templates
	forge build
rebuild: clean build
clean:
	forge clean
install: init
init:
	git submodule update --init --recursive
	git update-index --assume-unchanged playground/*
	forge install
	cd lib/forge-deploy && cargo build --release && cp target/release/forge-deploy ../../forge-deploy;
test:
	forge test -vv
test-gas-report:
	forge test -vv --gas-report
trace:
	forge test -vvvv 
remappings:
	forge remappings > remappings.txt
check-console-log:
ifneq ($(FILES_CONTAINING_CONSOLE),)
	$(error $(FILES_CONTAINING_CONSOLE) contains console.log)
endif
ifneq ($(FILES_CONTAINING_CONSOLE2),)
	$(error $(FILES_CONTAINING_CONSOLE2) contains console2.log)
endif

check-git-clean:
	@git diff --quiet || ( echo "This command requires clean working and staging areas, including no untracked files." && exit 1 )

_deploy-simulation: build check-console-log
ifdef SCRIPT
	echo "Simulating $(SCRIPT_DIR)/$(SCRIPT).s.sol...";
	forge script $(SCRIPT_DIR)/$(SCRIPT).s.sol --rpc-url $(rpc) --private-key $(pk) -vvvv;
else
	$(error SCRIPT must be defined)
endif

_deploy: build check-console-log clean
ifdef SCRIPT
	echo "Running $(SCRIPT_DIR)/$(SCRIPT).s.sol...";
	forge script $(SCRIPT_DIR)/$(SCRIPT).s.sol --rpc-url $(rpc) --private-key $(pk) --broadcast --verify --etherscan-api-key $(etherscan_key) -vvvv;
	./forge-deploy sync;
else
	$(error SCRIPT must be defined)
endif

_deploy-resume: build check-console-log
ifdef SCRIPT
	echo "Resuming $(SCRIPT_DIR)/$(SCRIPT).s.sol...";
	forge script $(SCRIPT_DIR)/$(SCRIPT).s.sol --rpc-url $(rpc) --private-key $(pk) --resume --verify --etherscan-api-key $(etherscan_key) -vvvv;
	./forge-deploy sync;
else
	$(error SCRIPT must be defined)
endif

playground: FOUNDRY_TEST:=playground
playground:
	forge test --match-path playground/Playground.t.sol --match-contract Playground -vv
playground-trace: FOUNDRY_TEST:=playground
playground-trace:
	forge test --match-path playground/Playground.t.sol --match-contract Playground -vvvv --gas-report

## Generate script/test from template example
gen-test:
	$(shell cp templates/Test.t.sol test/ )
gen-script:
	$(shell cp templates/Script.s.sol script/ )
gen-deploy:
	$(shell cp templates/Deploy.s.sol script/ )
gen-tx-sender:
	$(shell cp templates/TxSender.s.sol script/ )
gen-contract:
	$(shell cp templates/Contract.sol src/periphery/ )
gen-interface:
	$(shell cp templates/IContract.sol src/interfaces/ )
gen-cauldron-deploy:
	$(shell cp templates/CauldronDeploy.s.sol script/ )
gen: gen-test gen-script

## Mainnet
mainnet-deploy-simulation: rpc:=${MAINNET_RPC_URL}
mainnet-deploy-simulation: pk:=${PRIVATE_KEY}
mainnet-deploy-simulation: _deploy-simulation
mainnet-deploy: chain_id:=1
mainnet-deploy: chain_name:=mainnet
mainnet-deploy: rpc:=${MAINNET_RPC_URL}
mainnet-deploy: pk:=${PRIVATE_KEY}
mainnet-deploy: etherscan_key:=${MAINNET_ETHERSCAN_KEY}
mainnet-deploy: _deploy
mainnet-deploy-resume: rpc:=${MAINNET_RPC_URL}
mainnet-deploy-resume: pk:=${PRIVATE_KEY}
mainnet-deploy-resume: etherscan_key:=${MAINNET_ETHERSCAN_KEY}
mainnet-deploy-resume: _deploy-resume

## Avalanche
avalanche-deploy-simulation: rpc:=${AVALANCHE_RPC_URL}
avalanche-deploy-simulation: pk:=${PRIVATE_KEY}
avalanche-deploy-simulation: _deploy-simulation
avalanche-deploy: chain_id:=43114
avalanche-deploy: chain_name:=avalanche
avalanche-deploy: rpc:=${AVALANCHE_RPC_URL}
avalanche-deploy: pk:=${PRIVATE_KEY}
avalanche-deploy: etherscan_key:=${AVALANCHE_ETHERSCAN_KEY}
avalanche-deploy: _deploy
avalanche-deploy-resume: rpc:=${AVALANCHE_RPC_URL}
avalanche-deploy-resume: pk:=${PRIVATE_KEY}
avalanche-deploy-resume: etherscan_key:=${AVALANCHE_ETHERSCAN_KEY}
avalanche-deploy-resume: _deploy-resume

## Arbitrum
arbitrum-deploy-simulation: rpc:=${ARBITRUM_RPC_URL}
arbitrum-deploy-simulation: pk:=${PRIVATE_KEY}
arbitrum-deploy-simulation: _deploy-simulation
arbitrum-deploy: chain_name:=arbitrum
arbitrum-deploy: chain_id:=42161
arbitrum-deploy: rpc:=${ARBITRUM_RPC_URL}
arbitrum-deploy: pk:=${PRIVATE_KEY}
arbitrum-deploy: etherscan_key:=${ARBITRUM_ETHERSCAN_KEY}
arbitrum-deploy: _deploy
arbitrum-deploy-resume: rpc:=${ARBITRUM_RPC_URL}
arbitrum-deploy-resume: pk:=${PRIVATE_KEY}
arbitrum-deploy-resume: etherscan_key:=${ARBITRUM_ETHERSCAN_KEY}
arbitrum-deploy-resume: _deploy-resume

## Optimism
optimism-deploy-simulation: rpc:=${OPTIMISM_RPC_URL}
optimism-deploy-simulation: pk:=${PRIVATE_KEY}
optimism-deploy-simulation: _deploy-simulation
optimism-deploy: chain_name:=optimism
optimism-deploy: chain_id:=10
optimism-deploy: rpc:=${OPTIMISM_RPC_URL}
optimism-deploy: pk:=${PRIVATE_KEY}
optimism-deploy: etherscan_key:=${OPTIMISM_ETHERSCAN_KEY}
optimism-deploy: _deploy
optimism-deploy-resume: rpc:=${OPTIMISM_RPC_URL}
optimism-deploy-resume: pk:=${PRIVATE_KEY}
optimism-deploy-resume: etherscan_key:=${OPTIMISM_ETHERSCAN_KEY}
optimism-deploy-resume: _deploy-resume

## Fantom
fantom-deploy-simulation: rpc:=${FANTOM_RPC_URL}
fantom-deploy-simulation: pk:=${PRIVATE_KEY}
fantom-deploy-simulation: _deploy-simulation
fantom-deploy: chain_name:=fantom
fantom-deploy: chain_id:=250
fantom-deploy: rpc:=${FANTOM_RPC_URL}
fantom-deploy: pk:=${PRIVATE_KEY}
fantom-deploy: etherscan_key:=${FANTOM_ETHERSCAN_KEY}
fantom-deploy: _deploy
fantom-deploy-resume: rpc:=${FANTOM_RPC_URL}
fantom-deploy-resume: pk:=${PRIVATE_KEY}
fantom-deploy-resume: etherscan_key:=${FANTOM_ETHERSCAN_KEY}
fantom-deploy-resume: _deploy-resume

## Matic
polygon-deploy-simulation: rpc:=${POLYGON_RPC_URL}
polygon-deploy-simulation: pk:=${PRIVATE_KEY}
polygon-deploy-simulation: _deploy-simulation
polygon-deploy: chain_name:=polygon
polygon-deploy: chain_id:=137
polygon-deploy: rpc:=${POLYGON_RPC_URL}
polygon-deploy: pk:=${PRIVATE_KEY}
polygon-deploy: etherscan_key:=${POLYGON_ETHERSCAN_KEY}
polygon-deploy: _deploy
polygon-deploy-resume: rpc:=${POLYGON_RPC_URL}
polygon-deploy-resume: pk:=${PRIVATE_KEY}
polygon-deploy-resume: etherscan_key:=${POLYGON_ETHERSCAN_KEY}
polygon-deploy-resume: _deploy-resume

## BSC
bsc-deploy-simulation: rpc:=${BSC_RPC_URL}
bsc-deploy-simulation: pk:=${PRIVATE_KEY}
bsc-deploy-simulation: _deploy-simulation
bsc-deploy: chain_name:=bsc
bsc-deploy: chain_id:=56
bsc-deploy: rpc:=${BSC_RPC_URL}
bsc-deploy: pk:=${PRIVATE_KEY}
bsc-deploy: etherscan_key:=${BSC_ETHERSCAN_KEY}
bsc-deploy: _deploy
bsc-deploy-resume: rpc:=${BSC_RPC_URL}
bsc-deploy-resume: pk:=${PRIVATE_KEY}
bsc-deploy-resume: etherscan_key:=${BSC_ETHERSCAN_KEY}
bsc-deploy-resume: _deploy-resume

.PHONY: test test-archives playground check-console-log check-git-clean gen
.SILENT: deploy-simulation deploy deploy-resume