-include .env.defaults
-include .env
export

SCRIPT_DIR = ./script
TEST_DIR = ./test
FILES_CONTAINING_CONSOLE := $(shell grep -rlw --max-count=1 --include=\*.sol 'src' -e 'console\.sol')
FILES_CONTAINING_CONSOLE2 := $(shell grep -rlw --max-count=1 --include=\*.sol 'src' -e 'console2\.sol')
ARCHIVE_SCRIPT_FILES = $(wildcard ./archive/script/*.s.sol)
ARCHIVE_TEST_FILES = $(wildcard ./archive/test/*.t.sol)

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

test-archive-no-git-check:
	-@mkdir -p ./cache/backup 2>/dev/null ||:
	-@mv $(SCRIPT_DIR)/*.s.sol ./cache/backup 2>/dev/null ||:
	-@mv $(TEST_DIR)/*.t.sol ./cache/backup 2>/dev/null ||:
	-@cp $(ARCHIVE_SCRIPT_FILES) $(SCRIPT_DIR) 2>/dev/null ||:
	-@cp $(ARCHIVE_TEST_FILES) $(TEST_DIR) 2>/dev/null ||:
	-@forge test -vv ||:
	-@rm $(SCRIPT_DIR)/*.s.sol $(TEST_DIR)/*.t.sol 2>/dev/null ||:
	-@mv ./cache/backup/*.s.sol $(SCRIPT_DIR) 2>/dev/null ||:
	-@mv ./cache/backup/*.t.sol $(TEST_DIR) 2>/dev/null ||:

test-archive: check-git-clean test-archive-no-git-check
test-archives: test-archive
test-archives-no-git-check: test-archive-no-git-check

deploy-simulation: check-console-log
	$(foreach file, $(wildcard $(SCRIPT_DIR)/*.s.sol), \
		echo "Simulating $(file)..."; \
		forge script $(file) --rpc-url $(rpc) --private-key $(pk) -vvvv; \
	)
deploy: check-console-log
	$(foreach file, $(wildcard $(SCRIPT_DIR)/*.s.sol), \
		echo "Running $(file)..."; \
		forge script $(file) --rpc-url $(rpc) --private-key $(pk) --broadcast --verify --etherscan-api-key $(etherscan_key) -vvvv; \
	)
deploy-resume: check-console-log
	$(foreach file, $(wildcard $(SCRIPT_DIR)/*.s.sol), \
		echo "Resuming $(file)..."; \
		forge script $(file) --rpc-url $(rpc) --private-key $(pk) --resume --verify --etherscan-api-key $(etherscan_key) -vvvv; \
	)

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
gen: gen-test gen-script

## Mainnet
mainnet-deploy-simulation: rpc:=${MAINNET_RPC_URL}
mainnet-deploy-simulation: pk:=${PRIVATE_KEY}
mainnet-deploy-simulation: deploy-simulation
mainnet-deploy: rpc:=${MAINNET_RPC_URL}
mainnet-deploy: pk:=${PRIVATE_KEY}
mainnet-deploy: etherscan_key:=${MAINNET_ETHERSCAN_KEY}
mainnet-deploy: deploy
mainnet-deploy-resume: rpc:=${MAINNET_RPC_URL}
mainnet-deploy-resume: pk:=${PRIVATE_KEY}
mainnet-deploy-resume: etherscan_key:=${MAINNET_ETHERSCAN_KEY}
mainnet-deploy-resume: deploy-resume

## Avalanche
avalanche-deploy-simulation: rpc:=${AVALANCHE_RPC_URL}
avalanche-deploy-simulation: pk:=${PRIVATE_KEY}
avalanche-deploy-simulation: deploy-simulation
avalanche-deploy: rpc:=${AVALANCHE_RPC_URL}
avalanche-deploy: pk:=${PRIVATE_KEY}
avalanche-deploy: etherscan_key:=${SNOWTRACE_ETHERSCAN_KEY}
avalanche-deploy: deploy
avalanche-deploy-resume: rpc:=${AVALANCHE_RPC_URL}
avalanche-deploy-resume: pk:=${PRIVATE_KEY}
avalanche-deploy-resume: etherscan_key:=${SNOWTRACE_ETHERSCAN_KEY}
avalanche-deploy-resume: deploy-resume

## Optimism
optimism-deploy-simulation: rpc:=${OPTIMISM_RPC_URL}
optimism-deploy-simulation: pk:=${PRIVATE_KEY}
optimism-deploy-simulation: deploy-simulation
optimism-deploy: rpc:=${OPTIMISM_RPC_URL}
optimism-deploy: pk:=${PRIVATE_KEY}
optimism-deploy: etherscan_key:=${OPTIMISM_ETHERSCAN_KEY}
optimism-deploy: deploy
optimism-deploy-resume: rpc:=${OPTIMISM_RPC_URL}
optimism-deploy-resume: pk:=${PRIVATE_KEY}
optimism-deploy-resume: etherscan_key:=${OPTIMISM_ETHERSCAN_KEY}
optimism-deploy-resume: deploy-resume

## Fantom
fantom-deploy-simulation: rpc:=${FANTOM_RPC_URL}
fantom-deploy-simulation: pk:=${PRIVATE_KEY}
fantom-deploy-simulation: deploy-simulation
fantom-deploy: rpc:=${FANTOM_RPC_URL}
fantom-deploy: pk:=${PRIVATE_KEY}
fantom-deploy: etherscan_key:=${FTMSCAN_ETHERSCAN_KEY}
fantom-deploy: deploy
fantom-deploy-resume: rpc:=${FANTOM_RPC_URL}
fantom-deploy-resume: pk:=${PRIVATE_KEY}
fantom-deploy-resume: etherscan_key:=${FTMSCAN_ETHERSCAN_KEY}
fantom-deploy-resume: deploy-resume

.PHONY: test test-archives playground check-console-log check-git-clean gen
.SILENT: deploy-simulation deploy deploy-resume
