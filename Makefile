-include .env

.PHONY: all test clean deploy fund help install snapshot format anvil deploy-anvil

FIRST_ANVIL_PRIVATE_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

all: remove build test

# Clean the repo
clean :; forge clean

# Remove modules
remove :; rm -rf ../.gitmodules && rm -rf ../.git/modules/* && rm -rf lib && touch ../.gitmodules && git add . && git commit -m "modules"

install :; forge install foundry-rs/forge-std --no-commit && forge install openzeppelin/openzeppelin-contracts --no-commit 

# Update Dependencies
update:; forge update

build:; forge build

test :; forge test 

snapshot :; forge snapshot

format :; forge fmt

anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 10 --chain-id 1337

coverage :; forge coverage 

coverage-report :; forge coverage --report debug > coverage-report.txt

slither :; slither . --config-file slither.config.json 

aderyn :; aderyn .

deploy-usdc-placeholder :; forge script ./script/USDCPlaceholder.s.sol \
	--interactives 1 \
	--rpc-url ${SEPOLIA_RPC_URL} \
	--legacy \
	--broadcast

deploy-dtsla :; forge script ./script/dTSLADeploy.s.sol:dTSLADeploy \
	--interactives 1 \
	--rpc-url ${SEPOLIA_RPC_URL} \
	--legacy \
	--verify \
	--etherscan-api-key ${ETHERSCAN_API_KEY} \
	--broadcast
	