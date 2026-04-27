# Trustless Monero Bridge Integration

## Overview

This document explains how to replace trusted oracles in [hookedMonero](https://github.com/madschristensen99/hookedMonero) with **verifiable zkTLS proofs** using Reclaim Protocol.

## Problem with Current Architecture

hookedMonero currently uses **trusted oracles** for:
1. **Price feeds** (Pyth oracle) - Centralized price data
2. **Burn confirmation** - Trusted oracle confirms XMR was sent

**Risks:**
- Single point of failure
- Centralization
- Oracle manipulation
- Censorship vulnerability

## Solution: zkTLS Verifiable Oracles

Replace trusted oracles with **cryptographic proofs** from Monero RPC nodes using zkFetch.

### Architecture Comparison

#### Before (Trusted):
```
┌─────────────┐
│   Monero    │
│  Mainnet    │
└──────┬──────┘
       │
       │ 1. LP sends XMR
       ↓
┌─────────────┐
│   Oracle    │ ← TRUSTED (single point of failure)
│  (Pyth/etc) │
└──────┬──────┘
       │ 2. Oracle confirms
       ↓
┌─────────────┐
│  Ethereum   │
│   Bridge    │
└─────────────┘
```

#### After (Trustless):
```
┌─────────────┐
│   Monero    │
│  RPC Node   │ ← Any public node
└──────┬──────┘
       │
       │ 1. zkFetch generates proof
       ↓
┌─────────────┐
│   zkTLS     │ ← Cryptographic verification
│   Proof     │
└──────┬──────┘
       │ 2. On-chain verification
       ↓
┌─────────────┐
│  Ethereum   │
│   Bridge    │
└─────────────┘
```

## Implementation

### 1. MoneroTxResolver Contract

Located at: `contracts/resolvers/MoneroTxResolver.sol`

**Features:**
- Verifies Monero transaction existence
- Validates transaction amount (in piconeros)
- Checks confirmation count
- Prevents proof replay attacks
- Fully on-chain verification

**Configuration:**
```solidity
struct Config {
    address reclaimAddress;      // Reclaim verifier
    string expectedTxHash;       // Monero tx hash
    string expectedRecipient;    // Monero address
    uint256 minAmount;           // Min amount in piconeros
    uint256 minConfirmations;    // Min confirmations
    bool fulfilled;              // Verification status
}
```

### 2. Integration with hookedMonero

#### Burn Flow (Ethereum → Monero)

**Current Flow:**
1. User requests burn with destination Monero address
2. wXMR locked in contract
3. **Oracle watches for XMR transfer** ← TRUSTED
4. **Oracle confirms transfer** ← TRUSTED
5. Burn finalized

**New Flow:**
1. User requests burn with destination Monero address
2. wXMR locked in contract
3. LP sends XMR to user's Monero address
4. **User generates zkTLS proof** from Monero RPC node ← TRUSTLESS
5. **MoneroTxResolver verifies proof** on-chain ← TRUSTLESS
6. Burn finalized

#### Code Changes

**In WrappedMonero.sol:**

```solidity
// Add MoneroTxResolver
import {MoneroTxResolver} from "./resolvers/MoneroTxResolver.sol";

contract WrappedMonero {
    MoneroTxResolver public txResolver;
    
    // Map burn requests to escrow IDs
    mapping(uint256 => uint256) public burnToEscrow;
    
    function requestBurn(
        uint256 amount,
        string calldata moneroAddress
    ) external returns (uint256 burnId) {
        // Lock wXMR
        _burn(msg.sender, amount);
        
        // Create escrow with MoneroTxResolver
        uint256 escrowId = _createEscrow(amount, moneroAddress);
        burnToEscrow[burnId] = escrowId;
        
        emit BurnRequested(burnId, msg.sender, amount, moneroAddress);
    }
    
    function completeBurn(
        uint256 burnId,
        bytes calldata txProof
    ) external {
        uint256 escrowId = burnToEscrow[burnId];
        
        // Submit zkTLS proof to MoneroTxResolver
        txResolver.submitProof(escrowId, txProof);
        
        // Check if condition met
        require(txResolver.isConditionMet(escrowId), "Proof not verified");
        
        // Finalize burn
        _finalizeBurn(burnId);
    }
}
```

### 3. Price Feed Oracle Replacement

**Current:** Pyth oracle for XMR/USD price

**New:** zkTLS proof from cryptocurrency price APIs

**Supported APIs:**
- CoinGecko: `https://api.coingecko.com/api/v3/simple/price?ids=monero&vs_currencies=usd`
- CoinMarketCap: `https://pro-api.coinmarketcap.com/v1/cryptocurrency/quotes/latest`
- Binance: `https://api.binance.com/api/v3/ticker/price?symbol=XMRUSDT`

**Benefits:**
- Multiple price sources
- Decentralized
- Censorship-resistant
- No API keys needed (for public endpoints)

### 4. Testing

#### Test Monero RPC Proof Generation

```bash
# Test basic RPC connectivity
node scripts/testMoneroRPC.js

# Test transaction proof generation
node scripts/testMoneroTxProof.js
```

#### Expected Output

```
✅ Proof generated successfully!
✅ Proof verified successfully!

📦 Proof Details:
   Provider: http
   Proof Identifier: 0x...
   Transaction Hash: a1b2c3d4...
   Confirmations: 10
   Amount: 1000000000000 (1 XMR)
```

### 5. Deployment Steps

1. **Deploy MoneroTxResolver**
   ```bash
   forge script script/DeployMoneroTxResolver.s.sol \
     --rpc-url $UNICHAIN_RPC_URL \
     --broadcast
   ```

2. **Update WrappedMonero Contract**
   - Add MoneroTxResolver integration
   - Update burn flow to use zkTLS proofs
   - Remove trusted oracle dependencies

3. **Deploy Mock Reclaim Verifier** (for testing)
   ```bash
   forge script script/DeployZkFetchVerifier.s.sol \
     --rpc-url $UNICHAIN_RPC_URL \
     --broadcast
   ```

4. **Test End-to-End**
   - Request burn
   - LP sends XMR
   - Generate zkTLS proof
   - Submit proof on-chain
   - Verify burn completion

### 6. Security Considerations

#### Proof Replay Protection
- Each proof identifier can only be used once
- Prevents double-spending attacks

#### Confirmation Requirements
- Configurable minimum confirmations (e.g., 10 blocks)
- Prevents chain reorganization attacks

#### Amount Verification
- Proof must show exact or greater amount
- Prevents partial payment attacks

#### Multiple RPC Nodes
- User can use any Monero RPC node
- Decentralized verification
- No single point of failure

### 7. Gas Optimization

**Proof Verification Cost:**
- Reclaim proof verification: ~200k gas
- JSON parsing: ~50k gas
- Total: ~250k gas per burn

**Optimization Strategies:**
1. Batch multiple burns
2. Use calldata compression
3. Optimize JSON parsing
4. Cache verified proofs

### 8. Future Enhancements

#### Multi-Proof Verification
- Require proofs from N different RPC nodes
- Increases security through redundancy

#### Automated Proof Generation
- Browser extension generates proofs automatically
- Seamless UX for users

#### Cross-Chain Price Feeds
- Use zkTLS for all price data
- Fully decentralized pricing

#### Privacy Enhancements
- Combine with Monero view keys
- Prove amount without revealing transaction

## Benefits Summary

### Decentralization
✅ No trusted oracles
✅ Any Monero RPC node works
✅ Censorship-resistant

### Security
✅ Cryptographic verification
✅ Replay protection
✅ Confirmation requirements

### Privacy
✅ zkTLS preserves privacy
✅ No centralized data collection
✅ Monero privacy maintained

### Cost
✅ ~250k gas per verification
✅ No oracle subscription fees
✅ No API keys needed

## Resources

- **MoneroTxResolver Contract:** `contracts/resolvers/MoneroTxResolver.sol`
- **Test Scripts:** `scripts/testMoneroRPC.js`, `scripts/testMoneroTxProof.js`
- **Reclaim Protocol:** https://reclaimprotocol.org
- **Monero RPC Docs:** https://www.getmonero.org/resources/developer-guides/daemon-rpc.html
- **hookedMonero:** https://github.com/madschristensen99/hookedMonero

## Next Steps

1. ✅ Test zkFetch with Monero RPC nodes
2. ✅ Create MoneroTxResolver contract
3. ⏳ Deploy to Unichain testnet
4. ⏳ Integrate with hookedMonero
5. ⏳ End-to-end testing
6. ⏳ Mainnet deployment

---

**Status:** Ready for integration testing
**Last Updated:** April 27, 2026
