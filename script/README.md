# Deployment & Execution Scripts

This directory contains Forge scripts for deploying and interacting with the escrow system on Arbitrum Sepolia.

## Main Scripts

### Deployment

- **`DeployUnifiedE2E.s.sol`** - Deploy all contracts (SimpleEscrow + all three resolvers)
  ```bash
  forge script script/DeployUnifiedE2E.s.sol --rpc-url arbitrum_sepolia --broadcast --verify
  ```

- **`CompleteE2E.s.sol`** - Deploy and test all three resolvers in one transaction
  ```bash
  forge script script/CompleteE2E.s.sol:CompleteE2E --rpc-url arbitrum_sepolia --broadcast
  ```

### Chainlink Functions

- **`CreateChainlinkSubscription.s.sol`** - Create a new Chainlink Functions subscription
  ```bash
  forge script script/CreateChainlinkSubscription.s.sol:CreateChainlinkSubscription --rpc-url arbitrum_sepolia --broadcast
  ```

- **`CreateChainlinkFunctionsEscrowOnly.s.sol`** - Create escrow with Chainlink Functions
  ```bash
  forge script script/CreateChainlinkFunctionsEscrowOnly.s.sol:CreateChainlinkFunctionsEscrowOnly --rpc-url arbitrum_sepolia --broadcast
  ```

- **`CheckAndRelease.s.sol`** - Check if Functions request fulfilled and release escrow
  ```bash
  forge script script/CheckAndRelease.s.sol --rpc-url arbitrum_sepolia --broadcast
  ```

### Individual Deployments

- `DeployChainlinkPriceFeedResolver.s.sol` - Deploy price feed resolver only
- `DeployChainlinkFunctionsResolver.s.sol` - Deploy functions resolver only
- `DeployReclaimResolver.s.sol` - Deploy Reclaim resolver only
- `DeploySimpleEscrow.s.sol` - Deploy escrow contract only

## Environment Variables

Required in `.env`:
```bash
PRIVATE_KEY=0x...
ARBITRUM_SEPOLIA_RPC_URL=https://sepolia-rollup.arbitrum.io/rpc
ETHERSCAN_API_KEY=your_arbiscan_api_key
```

## Deployed Contracts (Arbitrum Sepolia)

| Contract | Address |
|----------|---------|
| SimpleEscrow | `0xAF4E10197Ed7b823c0ef2716431ADB69aB30Ce0D` |
| ChainlinkPriceFeedResolver | `0x23D3A5984043E9bF04D796b65DF67a687163Ce65` |
| ChainlinkFunctionsResolver | `0xEaec0247A15103845af146f8700826940A4B42A3` |
| ReclaimResolver | `0xc7b41B0Ad8d0F561eDe27fC7C467c1BD8250e792` |
