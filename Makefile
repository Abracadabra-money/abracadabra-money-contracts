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
 ifeq (, $(shell which nl))
 $(error "nl command not found")
 endif
 ifeq (, $(shell which sed))
 $(error "sed command not found")
 endif

build:
	forge build
rebuild: clean build
clean:
	forge clean
install: init
init:
	git submodule update --init --recursive
	git update-index --assume-unchanged playground/*
	forge install
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

deploy-simulation: check-console-log
ifdef SCRIPT
	echo "Simulating $(SCRIPT_DIR)/$(SCRIPT).s.sol...";
	forge script $(SCRIPT_DIR)/$(SCRIPT).s.sol --rpc-url $(rpc) --private-key $(pk) -vvvv;
else
	$(error SCRIPT must be defined)
endif

deploy: check-console-log clean
ifdef SCRIPT
	echo "Running $(SCRIPT_DIR)/$(SCRIPT).s.sol...";
	forge script $(SCRIPT_DIR)/$(SCRIPT).s.sol --rpc-url $(rpc) --private-key $(pk) --broadcast --verify --etherscan-api-key $(etherscan_key) -vvvv;
	-$(call create-deployments,$(SCRIPT_DIR)/$(SCRIPT).s.sol,$(chain_id),$(chain_name))
else
	$(error SCRIPT must be defined)
endif

_parse-deployment: build
	$(foreach file, $(wildcard $(SCRIPT_DIR)/*.s.sol), \
		echo "Parsing $(file)... (chain: $(chain_id))"; \
		$(call create-deployments,$(file),$(chain_id),$(chain_name)) \
	)

deploy-resume: check-console-log
ifdef SCRIPT
	echo "Resuming $(SCRIPT_DIR)/$(SCRIPT).s.sol...";
	forge script $(SCRIPT_DIR)/$(SCRIPT).s.sol --rpc-url $(rpc) --private-key $(pk) --resume --verify --etherscan-api-key $(etherscan_key) -vvvv;
else
	$(error SCRIPT must be defined)
endif

define create-deployments
	$(eval $@RUN_LATEST = broadcast/$(notdir $(1))/$(2)/run-latest.json)
	-@mkdir -p ./deployments/$(3)/ 2>/dev/null ||:
	if [ -f "${$@RUN_LATEST}" ]; then \
		jq '.transactions[] | select(.transactionType == "CREATE") | [.contractName]' ${$@RUN_LATEST} | jq '.[]' | \
		nl | \
		while read n l; do \
			l=`echo $$l | sed 's/"//g'`; \
			printf "Creating $$l deployment..."; \
			outFolder=`find ./out -name $$l.json -exec dirname {} \;`; \
			jq -cs "{abi:.[].abi,compiler:.[].metadata.compiler,optimizer:.[].metadata.settings.optimizer}" $$outFolder/$$l.json > cache/part1.json; \
			jq ".transactions[] | select(.transactionType == \"CREATE\") | select(.contractName == \"$$l\") | del(.rpc)" ${$@RUN_LATEST} > cache/part2.json; \
			jq -s '.[0] * .[1]' cache/part2.json cache/part1.json > ./deployments/$(3)/$$l.json; \
			rm -f cache/part2.json cache/part1.json; \
			printf "[\e[32mOK\e[0m]\n"; \
		done; \
	fi
endef

playground: FOUNDRY_TEST:=playground
playground:
	forge test --match-path playground/Playground.t.sol -vv
playground-trace: FOUNDRY_TEST:=playground
playground-trace:
	forge test --match-path playground/Playground.t.sol -vvvv --gas-report

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
mainnet-deploy-simulation: deploy-simulation
mainnet-deploy: chain_id:=1
mainnet-deploy: chain_name:=mainnet
mainnet-deploy: rpc:=${MAINNET_RPC_URL}
mainnet-deploy: pk:=${PRIVATE_KEY}
mainnet-deploy: etherscan_key:=${MAINNET_ETHERSCAN_KEY}
mainnet-deploy: deploy
mainnet-deploy-resume: rpc:=${MAINNET_RPC_URL}
mainnet-deploy-resume: pk:=${PRIVATE_KEY}
mainnet-deploy-resume: etherscan_key:=${MAINNET_ETHERSCAN_KEY}
mainnet-deploy-resume: deploy-resume
mainnet-parse-deployment: chain_id:=1
mainnet-parse-deployment: chain_name:=mainnet
mainnet-parse-deployment: _parse-deployment

## Avalanche
avalanche-deploy-simulation: rpc:=${AVALANCHE_RPC_URL}
avalanche-deploy-simulation: pk:=${PRIVATE_KEY}
avalanche-deploy-simulation: deploy-simulation
avalanche-deploy: chain_id:=43114
avalanche-deploy: chain_name:=avalanche
avalanche-deploy: rpc:=${AVALANCHE_RPC_URL}
avalanche-deploy: pk:=${PRIVATE_KEY}
avalanche-deploy: etherscan_key:=${SNOWTRACE_ETHERSCAN_KEY}
avalanche-deploy: deploy
avalanche-deploy-resume: rpc:=${AVALANCHE_RPC_URL}
avalanche-deploy-resume: pk:=${PRIVATE_KEY}
avalanche-deploy-resume: etherscan_key:=${SNOWTRACE_ETHERSCAN_KEY}
avalanche-deploy-resume: deploy-resume
avalanche-parse-deployment: chain_id:=43114
avalanche-parse-deployment: chain_name:=avalanche
avalanche-parse-deployment: _parse-deployment

## Arbitrum
arbitrum-deploy-simulation: rpc:=${ARBITRUM_RPC_URL}
arbitrum-deploy-simulation: pk:=${PRIVATE_KEY}
arbitrum-deploy-simulation: deploy-simulation
arbitrum-deploy: chain_name:=arbitrum
arbitrum-deploy: chain_id:=42161
arbitrum-deploy: rpc:=${ARBITRUM_RPC_URL}
arbitrum-deploy: pk:=${PRIVATE_KEY}
arbitrum-deploy: etherscan_key:=${ARBISCAN_TOKEN}
arbitrum-deploy: deploy
arbitrum-deploy-resume: rpc:=${ARBITRUM_RPC_URL}
arbitrum-deploy-resume: pk:=${PRIVATE_KEY}
arbitrum-deploy-resume: etherscan_key:=${ARBISCAN_TOKEN}
arbitrum-deploy-resume: deploy-resume
arbitrum-parse-deployment: chain_id:=42161
arbitrum-parse-deployment: chain_name:=arbitrum
arbitrum-parse-deployment: _parse-deployment

## Optimism
optimism-deploy-simulation: rpc:=${OPTIMISM_RPC_URL}
optimism-deploy-simulation: pk:=${PRIVATE_KEY}
optimism-deploy-simulation: deploy-simulation
optimism-deploy: chain_name:=optimism
optimism-deploy: chain_id:=10
optimism-deploy: rpc:=${OPTIMISM_RPC_URL}
optimism-deploy: pk:=${PRIVATE_KEY}
optimism-deploy: etherscan_key:=${OPTIMISM_ETHERSCAN_KEY}
optimism-deploy: deploy
optimism-deploy-resume: rpc:=${OPTIMISM_RPC_URL}
optimism-deploy-resume: pk:=${PRIVATE_KEY}
optimism-deploy-resume: etherscan_key:=${OPTIMISM_ETHERSCAN_KEY}
optimism-deploy-resume: deploy-resume
optimism-parse-deployment: chain_id:=10
optimism-parse-deployment: chain_name:=optimism
optimism-parse-deployment: _parse-deployment

## Fantom
fantom-deploy-simulation: rpc:=${FANTOM_RPC_URL}
fantom-deploy-simulation: pk:=${PRIVATE_KEY}
fantom-deploy-simulation: deploy-simulation
fantom-deploy: chain_name:=fantom
fantom-deploy: chain_id:=250
fantom-deploy: rpc:=${FANTOM_RPC_URL}
fantom-deploy: pk:=${PRIVATE_KEY}
fantom-deploy: etherscan_key:=${FTMSCAN_ETHERSCAN_KEY}
fantom-deploy: deploy
fantom-deploy-resume: rpc:=${FANTOM_RPC_URL}
fantom-deploy-resume: pk:=${PRIVATE_KEY}
fantom-deploy-resume: etherscan_key:=${FTMSCAN_ETHERSCAN_KEY}
fantom-deploy-resume: deploy-resume
fantom-parse-deployment: chain_id:=250
fantom-parse-deployment: chain_name:=fantom
fantom-parse-deployment: _parse-deployment

.PHONY: test test-archives playground check-console-log check-git-clean gen
.SILENT: deploy-simulation deploy deploy-resume _parse-deployment