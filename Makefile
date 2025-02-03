-include .env

.PHONY: all test clean deploy 

build :; forge build

test :; forge test

install :; forge install cyfrin/foundry-devops@0.2.2 --no-commit && forge install smartcontractkit/chainlink-brownie-contracts@1.1.1 --no-commit && forge install foundry-rs/forge-std@v1.8.2 --no-commit && forge install transmissions11/solmate@v6 --no-commit

# deploy-sepolia :; forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url $(SEPOLIA_RPC_URL) --account myKeystore --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
deploy-sepolia :; forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv

deploy-sepolia-FundSubscription :; forge script script/Interactions.s.sol:FundSubscription --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast

deploy-sepolia-AddConsumer :; forge script script/Interactions.s.sol:AddConsumer --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast