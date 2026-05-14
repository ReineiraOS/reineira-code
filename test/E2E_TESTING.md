# End-to-End Testing Guide

This guide covers running comprehensive E2E tests for all three resolver types on Arbitrum Sepolia testnet.

## Overview

The unified E2E test suite validates:
1. **Chainlink Data Feeds** - Real-time price feed integration
2. **Chainlink Functions** - Decentralized oracle network (DON) for custom computation
3. **Reclaim Protocol** - zkTLS proofs for HTTP API verification

## Quick Start

### Run All Tests

```bash
# Run the unified E2E test suite
forge test --match-contract UnifiedE2E --fork-url $ARBITRUM_SEPOLIA_RPC_URL -vvv
```

### Run Individual Tests

```bash
# Test 1: Chainlink Data Feeds only
forge test --match-test test_1_ChainlinkDataFeeds --fork-url $ARBITRUM_SEPOLIA_RPC_URL -vvv

# Test 2: Chainlink Functions configuration
forge test --match-test test_2_ChainlinkFunctions --fork-url $ARBITRUM_SEPOLIA_RPC_URL -vvv

# Test 3: Reclaim Protocol
forge test --match-test test_3_ReclaimProtocol --fork-url $ARBITRUM_SEPOLIA_RPC_URL -vvv

# Test 4: All three in parallel
forge test --match-test test_4_AllThreeResolversInParallel --fork-url $ARBITRUM_SEPOLIA_RPC_URL -vvv
```

## Prerequisites

### 1. Environment Setup

Create a `.env` file with:

```bash
PRIVATE_KEY=0x...
ARBITRUM_SEPOLIA_RPC_URL=https://sepolia-rollup.arbitrum.io/rpc
ETHERSCAN_API_KEY=your_arbiscan_api_key
```

### 2. Get Testnet ETH

Get Arbitrum Sepolia ETH from:
- https://faucet.quicknode.com/arbitrum/sepolia
- https://www.alchemy.com/faucets/arbitrum-sepolia

## Deployment

### Deploy All Contracts

```bash
forge script script/DeployUnifiedE2E.s.sol \
  --rpc-url arbitrum_sepolia \
  --broadcast \
  --verify
```

This deploys:
- `SimpleEscrow` - Escrow contract for testing
- `ChainlinkPriceFeedResolver` - Data Feeds resolver
- `ChainlinkFunctionsResolver` - Functions resolver
- `ReclaimResolver` - Reclaim protocol resolver

## Test Details

### Test 1: Chainlink Data Feeds

**What it tests:**
- Deploys escrow with ETH/USD price feed condition
- Verifies condition is met when ETH > threshold
- Releases funds to beneficiary

**Requirements:**
- None (uses live Chainlink price feeds)

**Expected output:**
```
TEST 1: CHAINLINK DATA FEEDS
Current ETH/USD Price: $ 2847
Step 1: Create escrow with price feed condition
  Condition: ETH/USD > $ 2747
  Escrow ID: 0
Step 2: Check condition
  Condition met: true
Step 3: Release funds
  Funds released successfully!
[PASS] CHAINLINK DATA FEEDS TEST PASSED
```

### Test 2: Chainlink Functions (DON)

**What it tests:**
- Configures escrow with JavaScript source code
- Verifies configuration is stored correctly
- Shows how to execute request (requires funded subscription)

**Requirements for full test:**
1. Create subscription at https://functions.chain.link
2. Fund subscription with LINK tokens (get from https://faucets.chain.link/arbitrum-sepolia)
3. Add resolver as consumer
4. Call `functionsResolver.executeRequest(escrowId)`

**Expected output:**
```
TEST 2: CHAINLINK FUNCTIONS (DON)
Step 1: Create escrow with Chainlink Functions condition
  Source code: return Functions.encodeUint256(42);
  Expected result: 42
  Escrow ID: 0
Step 2: Verify configuration
  Configuration verified
Step 3: Check source code
  Source code stored correctly
NOTE: To fully test Chainlink Functions:
  1. Create subscription at https://functions.chain.link
  2. Fund subscription with LINK tokens
  3. Add resolver as consumer: 0x...
  4. Call functionsResolver.executeRequest(escrowId)
  5. Wait for DON to fulfill the request
[PASS] CHAINLINK FUNCTIONS CONFIGURATION TEST PASSED
```

### Test 3: Reclaim Protocol (zkTLS)

**What it tests:**
- Deploys mock Reclaim verifier
- Creates escrow with zkTLS proof condition
- Submits valid proof
- Releases funds when proof is verified

**Requirements:**
- None for testing (uses mock verifier)
- For production: Deploy real Reclaim verifier or use official one

**Expected output:**
```
TEST 3: RECLAIM PROTOCOL (zkTLS)
Step 1: Create escrow with Reclaim condition
  Provider: http
  Expected context address: 0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb
  Expected context message: payment_received
  Escrow ID: 0
Step 2: Prepare and submit zkTLS proof
  Proof submitted successfully
Step 3: Check condition
  Condition met: true
Step 4: Release funds
  Funds released successfully!
[PASS] RECLAIM PROTOCOL TEST PASSED
```

### Test 4: All Three Resolvers in Parallel

**What it tests:**
- Creates 3 escrows simultaneously with different resolvers
- Verifies all escrows are independent
- Releases escrows that meet conditions

**Expected output:**
```
TEST 4: ALL THREE RESOLVERS IN PARALLEL
Creating 3 escrows simultaneously...
Escrow 1 (Data Feed): 0
Escrow 2 (Functions): 1
Escrow 3 (Reclaim): 2
Checking conditions:
  Escrow 1 (Data Feed) met: true
  Escrow 2 (Functions) met: false
  Escrow 3 (Reclaim) met: false
[OK] Escrow 1 (Data Feed) released
[OK] Escrow 3 (Reclaim) released
[PASS] ALL THREE RESOLVERS WORKING IN PARALLEL
```

## Chainlink Resources

### Data Feeds (Price Feeds)

**Arbitrum Sepolia Feeds:**
- ETH/USD: `0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165`
- BTC/USD: `0x56a43EB56Da12C0dc1D972ACb089c06a5dEF8e69`
- LINK/USD: `0x0FB99723Aee6f420beAD13e6bBB79b7E6F034298`

**Documentation:**
- https://docs.chain.link/data-feeds
- https://docs.chain.link/data-feeds/price-feeds/addresses

### Chainlink Functions

**Arbitrum Sepolia Configuration:**
- Router: `0x234a5fb5Bd614a7AA2FfAB244D603abFA0Ac5C5C`
- DON ID: `0x66756e2d617262697472756d2d7365706f6c69612d3100000000000000000000`

**Documentation:**
- https://docs.chain.link/chainlink-functions
- https://docs.chain.link/chainlink-functions/getting-started
- https://functions.chain.link (subscription management)

**Get LINK tokens:**
- https://faucets.chain.link/arbitrum-sepolia

## Reclaim Protocol Resources

**Documentation:**
- https://dev.reclaimprotocol.org/
- https://docs.reclaimprotocol.org/

**Verifier Addresses:**
- Check official docs for deployed verifier addresses
- Or deploy your own using Reclaim SDK

## Troubleshooting

### RPC Error

```
Error: RPC error
```

**Solution:**
- Check `ARBITRUM_SEPOLIA_RPC_URL` is set in `.env`
- Try alternative RPC endpoints:
  - `https://sepolia-rollup.arbitrum.io/rpc`
  - Alchemy: `https://arb-sepolia.g.alchemy.com/v2/YOUR_KEY`
  - Infura: `https://arbitrum-sepolia.infura.io/v3/YOUR_KEY`

### Chainlink Functions Not Executing

```
Error: Subscription not funded
```

**Solution:**
1. Create subscription at https://functions.chain.link
2. Get LINK from https://faucets.chain.link/arbitrum-sepolia
3. Fund your subscription
4. Add resolver contract as consumer

### Price Feed Stale Data

```
Error: Data is stale
```

**Solution:**
- Increase `maxStaleness` parameter (e.g., 3600 for 1 hour)
- Check if feed is actively updated on Chainlink

## Production Deployment

### 1. Deploy Contracts

```bash
forge script script/DeployUnifiedE2E.s.sol \
  --rpc-url arbitrum_sepolia \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

### 2. Verify on Arbiscan

Contracts will be automatically verified if `--verify` flag is used.

Manual verification:
```bash
forge verify-contract \
  --chain-id 421614 \
  --compiler-version v0.8.25 \
  CONTRACT_ADDRESS \
  src/contracts/resolvers/ChainlinkPriceFeedResolver.sol:ChainlinkPriceFeedResolver
```

### 3. Test Live Integration

Use the test scripts to verify everything works:

```bash
# Test with real price feeds
forge test --match-test test_1_ChainlinkDataFeeds --fork-url $ARBITRUM_SEPOLIA_RPC_URL -vvv

# Test Reclaim with real verifier
# (update test to use real verifier address)
forge test --match-test test_3_ReclaimProtocol --fork-url $ARBITRUM_SEPOLIA_RPC_URL -vvv
```

## Next Steps

1. ✅ Run unified E2E tests
2. ✅ Deploy to Arbitrum Sepolia
3. ✅ Verify contracts on Arbiscan
4. ⏳ Set up Chainlink Functions subscription
5. ⏳ Integrate with real Reclaim verifier
6. ⏳ Create production escrows
7. ⏳ Monitor and test in production

## Support

- Chainlink Discord: https://discord.gg/chainlink
- Reclaim Discord: https://discord.gg/reclaim
- GitHub Issues: Create an issue in this repo
