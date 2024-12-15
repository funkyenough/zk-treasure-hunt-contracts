include .env

t:
	forge test -vv

tt:
	forge test -vvv

ttt:
	forge test -vvvv

deploy-anvil:
	forge script script/Deploy.s.sol:Deploy --account defaultKey

deploy-holesky:
	forge script script/Deploy.s.sol:Deploy --account 0xA4d9f --broadcast --chain-id $(HOLESKY_CHAIN_ID) --rpc-url $(HOLESKY_RPC_URL) --verify

deploy-sepolia:
	forge script script/Deploy.s.sol:Deploy --account 0xA4d9f --broadcast --chain-id $(SEPOLIA_CHAIN_ID) --rpc-url $(SEPOLIA_RPC_URL) --verify