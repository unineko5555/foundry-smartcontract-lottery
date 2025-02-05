-include .env

.PHONY: all test clean install deploy deploy-sepolia deploy-sepolia-FundSubscription deploy-sepolia-AddConsumer

NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast --sender $(SENDER_ADDRESS)
# if --network sepolia is used, then use sepolia stuff, otherwise anvil stuff
#--verifyをつけるとエラーになる、--legacyも削除
#--account defaultはcast wallet importで使う
ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --private-key $(SEPOLIA_PRIVATE_KEY) --broadcast --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvvv 
endif

build :; forge build

test :; forge test

install :; 
	forge install cyfrin/foundry-devops@0.2.2 --no-commit && \
	forge install smartcontractkit/chainlink-brownie-contracts@1.1.1 --no-commit && \
	forge install foundry-rs/forge-std@v1.8.2 --no-commit && \
	forge install transmissions11/solmate@v6 --no-commit

anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

deploy:
	@forge script script/DeployRaffle.s.sol:DeployRaffle $(NETWORK_ARGS)

createSubscrption:
	@forge script script/Interactions.s.sol:CreateSubscrption $(NETWORK_ARGS)

fundSubscription:
	@forge script script/Interactions.s.sol:FundSubscription $(NETWORK_ARGS)

addConsumer:
	@forge script script/Interactions.s.sol:AddConsumer $(NETWORK_ARGS)

#deploy済みのスマートコントラクトをEtherscanにverifyする
#EtherscanでVerify&Publishを行う
deploy verify-contract
	@forge verify-contract 0x2b7E8f5b40BECc4e36b06F20922EAC028B7cD743 src/Raffle.sol:Raffle --etherscan-api-key $(ETHERSCAN_API_KEY) --rpc-url $(SEPOLIA_RPC_URL) --show-standard-json-input > json.json