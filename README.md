# ReineiraOS Code

AI-assisted plugin development for ReineiraOS. Build condition resolvers and insurance policies with Claude Code.

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

| Command | What it does |
|---|---|
| `/new-resolver` | Build a condition resolver from a description |
| `/new-policy` | Build an insurance policy with FHE from a description |
| `/deploy` | Deploy any contract to Arbitrum Sepolia |
| `/test` | Run tests, diagnose and fix failures |
| `/audit` | Security audit against the protocol checklist |
| `/integrate` | Generate SDK code to attach your contract to an escrow |
| `/scaffold-test` | Generate tests for an existing contract |
| `/verify` | Verify a deployed contract on Arbiscan |

### Example

```
/new-resolver A resolver that verifies PayPal payment via zkTLS proof from Reclaim Protocol
```

Claude Code generates the Solidity contract, tests, and deployment script — all pre-configured for the ReineiraOS protocol.

## Manual workflow

```bash
# Compile
npm run compile

# Test
npm test

# Deploy
CONTRACT_NAME=MyResolver npm run deploy

# Verify on Arbiscan
npx hardhat verify --network arbitrumSepolia <address>
```

## Documentation

- [ReineiraOS Docs](https://reineira.io/docs)
- [Quick Start](https://reineira.io/docs/getting-started/quick-start)
- [Condition Plugins](https://reineira.io/docs/develop/condition-plugins)
- [Insurance Policies](https://reineira.io/docs/develop/insurance-policies)
- [Telegram](https://t.me/ReineiraOS)
