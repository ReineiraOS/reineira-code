# Test Suite

Comprehensive test coverage for the escrow system with Chainlink and Reclaim Protocol integrations.

## Test Files

### End-to-End Tests

- **`UnifiedE2E.fork.t.sol`** - Complete E2E test for all three resolvers
  - Tests Chainlink Data Feeds, Chainlink Functions, and Reclaim Protocol
  - Runs on Arbitrum Sepolia fork
  ```bash
  forge test --match-contract UnifiedE2E --fork-url $ARBITRUM_SEPOLIA_RPC_URL -vvv
  ```

### Resolver Tests

- **`ChainlinkPriceFeedResolver.t.sol`** - Unit tests for price feed resolver
- **`ChainlinkFunctionsResolver.t.sol`** - Unit tests for Functions resolver  
- **`ReclaimResolver.t.sol`** - Unit tests for Reclaim resolver

### Integration Tests

- **`ChainlinkEscrowIntegration.t.sol`** - Integration tests for Chainlink price feeds
- **`ChainlinkConditions.t.sol`** - Tests for various price conditions

## Running Tests

### All Tests
```bash
forge test
```

### Specific Test File
```bash
forge test --match-contract UnifiedE2E -vvv
```

### Fork Tests (Arbitrum Sepolia)
```bash
forge test --match-contract UnifiedE2E --fork-url $ARBITRUM_SEPOLIA_RPC_URL -vvv
```

### With Gas Report
```bash
forge test --gas-report
```

## Test Coverage

Run coverage report:
```bash
forge coverage
```

## Documentation

- `E2E_TESTING.md` - Detailed guide for running E2E tests
- `README_FORK_TESTS.md` - Guide for fork testing with Chainlink
- `TESTNET_DEPLOYMENTS.md` - Record of testnet deployments

## Live Test Results

All three resolvers tested successfully on Arbitrum Sepolia:
- ✅ Chainlink Data Feeds - Complete
- ✅ Chainlink Functions (DON) - Complete  
- ✅ Reclaim Protocol (zkTLS) - Complete

View contracts: https://sepolia.arbiscan.io/address/0xAF4E10197Ed7b823c0ef2716431ADB69aB30Ce0D
