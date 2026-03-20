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

| Command          | What it does                                           |
| ---------------- | ------------------------------------------------------ |
| `/new-resolver`  | Build a condition resolver from a description          |
| `/new-policy`    | Build an insurance policy with FHE from a description  |
| `/deploy`        | Deploy any contract to Arbitrum Sepolia                |
| `/test`          | Run tests, diagnose and fix failures                   |
| `/audit`         | Security audit against the protocol checklist          |
| `/integrate`     | Generate SDK code to attach your contract to an escrow |
| `/scaffold-test` | Generate tests for an existing contract                |
| `/verify`        | Verify a deployed contract on Arbiscan                 |

### Example

```
/new-resolver A resolver that verifies PayPal payment via zkTLS proof from Reclaim Protocol
```

Claude Code generates the Solidity contract, tests, and deployment script — all pre-configured for the ReineiraOS protocol.

## The ecosystem

| Repo | What you do there | Platform |
| ---- | ----------------- | -------- |
| [reineira-atlas](https://github.com/ReineiraOS/reineira-atlas) | Run the startup — strategy, ops, growth, compliance, pitch | 0.1 |
| **reineira-code** (this repo) | Build smart contracts — resolvers, policies, tests, deploy | 0.1 |
| [platform-modules](https://github.com/ReineiraOS/platform-modules) | Ship the product — backend, platform app, payment link | 0.1 |

All repos declare their platform compatibility in `reineira.json`. When the platform version bumps, breaking contract interface changes may require upgrading.

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

## Compatibility

| Component | Requirement             |
| --------- | ----------------------- |
| Platform  | ReineiraOS 0.1          |
| Solidity  | ^0.8.24                 |
| Hardhat   | ~2.26.x                 |
| SDK       | @reineira-os/sdk ^0.1.0 |
| cofhejs   | ^0.3.1                  |
| Node.js   | 18+                     |

## Documentation

- [ReineiraOS Docs](https://reineira.xyz/docs)
- [Quick Start](https://reineira.xyz/docs/getting-started/quick-start)
- [Condition Plugins](https://reineira.xyz/docs/develop/condition-plugins)
- [Insurance Policies](https://reineira.xyz/docs/develop/insurance-policies)
- [Telegram](https://t.me/ReineiraOS)

## License

MIT
