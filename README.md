# ReineiraOS Code

[![Platform](https://img.shields.io/badge/ReineiraOS-v0.1-blue)](https://reineira.xyz)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

AI-assisted plugin development for ReineiraOS. Build condition resolvers and insurance policies with Claude Code.

> **Platform 0.1** — Generates contracts compatible with ReineiraOS v0.1 interfaces. Check `reineira.json` for version details.

## Setup

```bash
git clone https://github.com/ReineiraOS/reineira-code.git
cd reineira-code
npm install --legacy-peer-deps
cp .env.example .env
# Add your private key and RPC URL to .env
```

## Usage

Open in an editor with Claude Code. Use slash commands:

| Command          | What it does                                               |
| ---------------- | ---------------------------------------------------------- |
| `/new-resolver`  | Build a condition resolver from a description              |
| `/new-policy`    | Build an insurance policy with FHE from a description      |
| `/deploy`        | Deploy any contract to Arbitrum Sepolia                    |
| `/test`          | Run tests, diagnose and fix failures                       |
| `/audit`         | Security audit against the protocol checklist              |
| `/integrate`     | Generate SDK code to attach your contract to an escrow     |
| `/scaffold-test` | Generate tests for an existing contract                    |
| `/verify`        | Verify a deployed contract on Arbiscan                     |

### Example

```
/new-resolver A resolver that verifies PayPal payment via zkTLS proof from Reclaim Protocol
```

Claude Code generates the Solidity contract, tests, and deployment script — all pre-configured for the ReineiraOS protocol.

## The ecosystem

| Repo                                                            | What you do there                                          | Platform |
| --------------------------------------------------------------- | ---------------------------------------------------------- | -------- |
| [reineira-atlas](https://github.com/ReineiraOS/reineira-atlas) | Run the startup — strategy, ops, growth, compliance, pitch | 0.1      |
| **reineira-code** (this repo)                                   | Build smart contracts — resolvers, policies, tests, deploy | 0.1      |
| [platform-modules](https://github.com/ReineiraOS/platform-modules) | Ship the product — backend, platform app, payment link  | 0.1      |

All repos declare their platform compatibility in `reineira.json`. When the platform version bumps, breaking contract interface changes may require upgrading.

## Manual workflow

```bash
# Compile
forge build

# Test
forge test

# Deploy
forge script script/DeployTimeLockResolver.s.sol --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --broadcast --verify

# Verify on Arbiscan (if not done during deployment)
forge verify-contract <address> <contract> --chain arbitrum-sepolia --etherscan-api-key $ETHERSCAN_API_KEY
```

## Reclaim zkFetch E2E Test (Live on Testnet)

A complete end-to-end test of the Reclaim Protocol zkFetch integration is deployed and working on **Arbitrum Sepolia**:

**Deployed Contracts:**
- **ReclaimResolver:** `0x5f6F022740320c49F3F3868a75599d7fE0ac65c9`
- **SimpleEscrow:** `0x58eba8b9258907bE0BEeAD6F25D7EEfda9735ff0`
- **ZkFetchVerifier (Mock):** `0x4a0Bd08E23AdEE060CB3a45C38A01268C6753b4d`

**Run the E2E test:**
```bash
# Ensure you have Reclaim credentials in .env
node scripts/zkFetchE2ETest.js
```

**What it does:**
1. Generates real zkTLS proof from GitHub API using Reclaim's zkFetch
2. Verifies proof cryptographically off-chain using Reclaim SDK
3. Submits proof to on-chain ReclaimResolver
4. Releases escrow funds when proof is valid
5. Demonstrates complete flow from API call → proof → on-chain settlement

**Note:** The on-chain verifier is currently a mock for testing. Real cryptographic verification happens off-chain in step 2. Production deployments should use Reclaim's production verifier contract.

## Chainlink Integration (Live on Testnet)

Full integration with **Chainlink Data Feeds** for price-based escrow conditions is deployed and tested on **Arbitrum Sepolia**:

**Deployed Contracts:**
- **ChainlinkPriceFeedResolver:** `0x49DDce54E0dCe041fE2ab3590515b640289cE2de`
- **Demo Escrow System:** `0xf2e42be96af8cf1c8f08d981c2d84d1e3c5a3b3a`

### Quick Start

**1. Deploy the resolver:**
```bash
forge script script/DeployChainlinkPriceFeedResolver.s.sol --rpc-url arbitrum_sepolia --broadcast --verify
```

**2. Create an escrow with Chainlink condition:**
```solidity
// Release when ETH/USD > $2000
bytes memory resolverData = abi.encode(
    0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165, // ETH/USD feed on Arbitrum Sepolia
    2000 * 10**8,                                 // $2000 threshold
    0,                                            // GreaterThan operator
    3600                                          // 1 hour max staleness
);

uint256 escrowId = escrow.createEscrow{value: 1 ether}(
    beneficiary,
    0x49DDce54E0dCe041fE2ab3590515b640289cE2de, // Resolver address
    resolverData
);
```

**3. Release when condition is met:**
```bash
cast send <escrow_address> "release(uint256)" <escrow_id> --rpc-url arbitrum_sepolia --private-key $PRIVATE_KEY
```

### Features

✅ **Real Chainlink Price Feeds** - ETH/USD, BTC/USD, LINK/USD on Arbitrum Sepolia  
✅ **All Comparison Operators** - >, >=, <, <=, ==, !=  
✅ **Staleness Protection** - Configurable max data age  
✅ **Multiple Feeds** - Each escrow can use different price feeds  
✅ **Comprehensive Tests** - 28 tests covering all condition outcomes  

### Run Tests

```bash
# Unit tests with mocks
forge test --match-contract ChainlinkPriceFeedResolver

# Integration tests with real Chainlink data
forge test --match-contract ChainlinkEscrowIntegration --fork-url $ARBITRUM_SEPOLIA_RPC_URL

# Comprehensive condition tests (all operators)
forge test --match-contract ChainlinkConditions --fork-url $ARBITRUM_SEPOLIA_RPC_URL
```

**See [docs/CHAINLINK_INTEGRATION.md](docs/CHAINLINK_INTEGRATION.md) for complete guide**

## Current Phase

**Status:** Active development with working testnet deployment

**What's working:**
- ✅ Reclaim zkFetch E2E test on Arbitrum Sepolia
- ✅ Chainlink Data Feeds integration (price oracles)
- ✅ Chainlink Functions integration (custom off-chain computation)
- ✅ Pluggable condition resolver architecture
- ✅ Base abstractions for oracle, prediction market, and zkTLS resolvers

**What's in progress:**
- 🔄 FHE dependency migration (cofhe v0.4.0 → v0.5.0) - **migration window: April 27, 12:00-15:00 UTC**
- 🔄 Production-ready concrete resolver implementations
- 🔄 Additional zkTLS provider integrations (TLSNotary, etc.)

**Known limitations:**
- FHE-dependent contracts (policies) temporarily excluded from compilation during FHE migration
- Mock verifier used for on-chain testing (real verification happens off-chain)

## Compatibility

| Component | Requirement             |
| --------- | ----------------------- |
| Platform  | ReineiraOS 0.1          |
| Solidity  | ^0.8.24                 |
| Foundry   | Latest                  |
| SDK       | @reineira-os/sdk ^0.1.0 |
| cofhejs   | ^0.5.0 (migrating)      |
| Reclaim   | @reclaimprotocol/zk-fetch ^0.8.0 |
| Chainlink | @chainlink/contracts ^1.3.0 |
| Node.js   | 18+                     |

## Documentation

- [ReineiraOS Docs](https://reineira.xyz/docs)
- [Quick Start](https://reineira.xyz/docs/getting-started/quick-start)
- [Condition Plugins](https://reineira.xyz/docs/develop/condition-plugins)
- [Insurance Policies](https://reineira.xyz/docs/develop/insurance-policies)
- [Telegram](https://t.me/ReineiraOS)

## Foundry Reference

This project uses Foundry for smart contract development:

- **Forge**: Ethereum testing framework
- **Cast**: CLI for interacting with contracts
- **Anvil**: Local Ethereum node for testing

For more details, see the [Foundry Book](https://book.getfoundry.sh/).

## License

MIT
