# Testnet Deployments - Arbitrum Sepolia

This document records all contracts deployed during live testing on Arbitrum Sepolia testnet.

**Last Updated:** May 1, 2026  
**Network:** Arbitrum Sepolia (Chain ID: 421614)  
**Block Explorer:** https://sepolia.arbiscan.io

---

## Chainlink Integration Tests

### Contracts Deployed

| Contract | Address | Arbiscan Link |
|----------|---------|---------------|
| **ChainlinkPriceFeedResolver** | `0x7eb4f1Ab119a4521AeBc31a11FF703D105B0FEFE` | [View](https://sepolia.arbiscan.io/address/0x7eb4f1Ab119a4521AeBc31a11FF703D105B0FEFE) |
| **SimpleEscrow** | `0xd506c61f232bce091b83fe224f7e57b2c6c94fed` | [View](https://sepolia.arbiscan.io/address/0xd506c61f232bce091b83fe224f7e57b2c6c94fed) |

### Transactions

| # | Action | Transaction Hash | Link |
|---|--------|------------------|------|
| 1 | Deploy ChainlinkPriceFeedResolver | `0x7800fc58456da9e4acf28f6da938bf5e086f07cbb87ca05538ed0f9cb6e434cf` | [View](https://sepolia.arbiscan.io/tx/0x7800fc58456da9e4acf28f6da938bf5e086f07cbb87ca05538ed0f9cb6e434cf) |
| 2 | Deploy SimpleEscrow | `0xb875894a9e3be1ddc358201edbd20174c6bc39859a65014e1ab44b2c53f7e0b1` | [View](https://sepolia.arbiscan.io/tx/0xb875894a9e3be1ddc358201edbd20174c6bc39859a65014e1ab44b2c53f7e0b1) |
| 3 | Create Escrow (0.001 ETH, ETH > $2000 condition) | `0xec00194536980f0fe0fb47bf3759d5951b9a9a0ffd465e784f93fa8ca2932ed1` | [View](https://sepolia.arbiscan.io/tx/0xec00194536980f0fe0fb47bf3759d5951b9a9a0ffd465e784f93fa8ca2932ed1) |
| 4 | Release Escrow (condition met) | `0x3962e0eec9105a94c1712bea313cacde370a4cfe4926ee1d1329f14e36a0f59b` | [View](https://sepolia.arbiscan.io/tx/0x3962e0eec9105a94c1712bea313cacde370a4cfe4926ee1d1329f14e36a0f59b) |

### Test Details

- **Escrow Amount:** 0.001 ETH
- **Condition:** ETH/USD > $2,000 (using Chainlink Price Feed)
- **ETH Price at test:** ~$2,313 (condition MET)
- **Result:** Successfully released when condition satisfied

---

## Reclaim Protocol (zkFetch) Tests

### Contracts Deployed

| Contract | Address | Arbiscan Link |
|----------|---------|---------------|
| **ZkFetchVerifier** (mock) | `0xfbdb1893d25f8039bb3e875f661ca6a1fa650015` | [View](https://sepolia.arbiscan.io/address/0xfbdb1893d25f8039bb3e875f661ca6a1fa650015) |
| **ReclaimResolver** | `0x0bc7a6f18d868b635f25f9c80f7d228f02bcc1b6` | [View](https://sepolia.arbiscan.io/address/0x0bc7a6f18d868b635f25f9c80f7d228f02bcc1b6) |
| **SimpleEscrow** | `0x2ac6ec4ead841034810d8d521c75b9a31f145026` | [View](https://sepolia.arbiscan.io/address/0x2ac6ec4ead841034810d8d521c75b9a31f145026) |

### Transactions

| # | Action | Transaction Hash | Link |
|---|--------|------------------|------|
| 1 | Deploy ZkFetchVerifier | `0x3cc608a24955db1c03c1b3d4a566f0ad05ca5d1f078e743a3d5a0f45afe96473` | [View](https://sepolia.arbiscan.io/tx/0x3cc608a24955db1c03c1b3d4a566f0ad05ca5d1f078e743a3d5a0f45afe96473) |
| 2 | Deploy ReclaimResolver | `0xb33ec6a2bb5fc7cd26b09b552627a28a326da0d7d3785084bc0d5000e258da5f` | [View](https://sepolia.arbiscan.io/tx/0xb33ec6a2bb5fc7cd26b09b552627a28a326da0d7d3785084bc0d5000e258da5f) |
| 3 | Deploy SimpleEscrow | `0x1132fabc1123308cf06c7baf9cff74b98f8ed31ace8edb7775db2a8b8ee89465` | [View](https://sepolia.arbiscan.io/tx/0x1132fabc1123308cf06c7baf9cff74b98f8ed31ace8edb7775db2a8b8ee89465) |
| 4 | Create Escrow (0.001 ETH) | `0x5640e7eabf450265e2bb2f17de268933fcace87f689a6bc8a6d1ca2794ab393a` | [View](https://sepolia.arbiscan.io/tx/0x5640e7eabf450265e2bb2f17de268933fcace87f689a6bc8a6d1ca2794ab393a) |
| 5 | Submit zkFetch Proof | `0xe0f8154ad0968234e0f4b1f34fdbafecc28f31da4dba24d63bd3b4b1a4698dc9` | [View](https://sepolia.arbiscan.io/tx/0xe0f8154ad0968234e0f4b1f34fdbafecc28f31da4dba24d63bd3b4b1a4698dc9) |
| 6 | Release Escrow | `0x4b7b9b63d010ff8ff2bdd132ee7b156de06e3ba68d5c10a4d24c8b7ff9a13f5f` | [View](https://sepolia.arbiscan.io/tx/0x4b7b9b63d010ff8ff2bdd132ee7b156de06e3ba68d5c10a4d24c8b7ff9a13f5f) |

### Test Details

- **Escrow Amount:** 0.001 ETH
- **Proof Source:** GitHub API (`api.github.com/users/octocat`)
- **Proof Type:** zkTLS (zero-knowledge TLS proof via Reclaim Protocol)
- **Verification:** Off-chain via Reclaim SDK, on-chain via mock verifier
- **Result:** Successfully released after proof submission

---

## Chainlink Price Feeds Used

| Asset | Feed Address | Arbiscan Link |
|-------|--------------|---------------|
| **ETH/USD** | `0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165` | [View](https://sepolia.arbiscan.io/address/0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165) |
| **BTC/USD** | `0x56a43EB56Da12C0dc1D972ACb089c06a5dEF8e69` | [View](https://sepolia.arbiscan.io/address/0x56a43EB56Da12C0dc1D972ACb089c06a5dEF8e69) |
| **LINK/USD** | `0x0FB99723Aee6f420beAD13e6bBB79b7E6F034298` | [View](https://sepolia.arbiscan.io/address/0x0FB99723Aee6f420beAD13e6bBB79b7E6F034298) |

---

## Summary

Total gas spent on all testnet operations: ~0.00008 ETH (~$0.20)

### What Was Tested

1. **ChainlinkPriceFeedResolver** - Oracle-based conditions using real Chainlink price feeds
2. **ReclaimResolver** - zkTLS proof verification for HTTP API data
3. **SimpleEscrow** - Integration with both resolver types

### Key Features Demonstrated

- ✅ Real-time price feed integration
- ✅ zkTLS proof generation and verification
- ✅ On-chain condition evaluation
- ✅ Automated escrow release based on external data
- ✅ Gas-efficient contract interactions

---

## Notes

- All contracts deployed on Arbitrum Sepolia testnet
- Chainlink feeds provide real market data (not mocked)
- Reclaim proofs are generated from live HTTP requests
- Escrow conditions were successfully evaluated and met
- Funds were automatically released when conditions satisfied
