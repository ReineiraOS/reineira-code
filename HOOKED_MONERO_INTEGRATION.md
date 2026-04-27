# hookedMonero + zkTLS Integration

## Architecture Overview

hookedMonero uses **two complementary privacy technologies**:

1. **ZK Circuit (PLONK)** - For minting (privacy-preserving proof of ownership)
2. **zkTLS (Reclaim)** - For burning (trustless oracle replacement)

## Why Both Are Needed

### ZK Circuit (Existing - Keep This!)

**Purpose:** Privacy-preserving proof of Monero transaction ownership

**What it proves:**
- ✅ User knows secret key `r` (without revealing it)
- ✅ `R = r·G` matches transaction public key
- ✅ Amount decryption using LP's view key
- ✅ Transaction and output inclusion in blockchain

**Why it's essential:**
- 🔐 Preserves Monero's privacy model
- 🛡️ Hides transaction secret key `r`
- 🎭 Doesn't reveal which UTXO was used
- 💎 Core innovation of hookedMonero

**Circuit constraints:** ~1,167 (efficient!)

### zkTLS (New - Add This!)

**Purpose:** Trustless oracle for burn confirmations

**What it proves:**
- ✅ Transaction exists on Monero blockchain
- ✅ Correct amount was sent
- ✅ Sufficient confirmations
- ✅ Data came from real Monero RPC node

**Why it's needed:**
- 🌐 Removes trusted oracle dependency
- 🔓 Decentralized verification
- 💰 No oracle subscription fees
- 🚫 Censorship-resistant

**Gas cost:** ~250k per verification

## Complete Flow Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    MINTING FLOW                         │
│              (Monero → Ethereum)                        │
└─────────────────────────────────────────────────────────┘

1. User sends XMR to LP's Monero address
   │
   ├─→ User has: transaction secret key r
   │
2. Generate PLONK proof (ZK Circuit)
   │
   ├─→ Prove: R = r·G (without revealing r)
   ├─→ Prove: Amount decryption
   ├─→ Prove: Merkle inclusion
   │
3. Submit proof to WrappedMonero contract
   │
   ├─→ PlonkVerifier verifies proof on-chain
   ├─→ Ed25519 signature verification
   │
4. Mint wXMR to user's Ethereum address
   │
   └─→ Privacy preserved! ✅


┌─────────────────────────────────────────────────────────┐
│                    BURNING FLOW                         │
│              (Ethereum → Monero)                        │
└─────────────────────────────────────────────────────────┘

1. User requests burn with Monero destination address
   │
   ├─→ wXMR locked in contract
   │
2. LP sends XMR to user's Monero address
   │
   ├─→ LP fulfills off-chain
   │
3. User generates zkTLS proof (NEW!)
   │
   ├─→ Call Monero RPC: get_transactions
   ├─→ Reclaim generates zkTLS proof
   ├─→ Prove: transaction exists
   ├─→ Prove: correct amount
   ├─→ Prove: confirmations >= threshold
   │
4. Submit zkTLS proof to MoneroTxResolver
   │
   ├─→ Reclaim verifier checks proof
   ├─→ Extract transaction data
   ├─→ Validate amount & confirmations
   │
5. Burn finalized, LP receives collateral back
   │
   └─→ Trustless! No oracle needed! ✅
```

## Technical Details

### Minting (ZK Circuit)

**Circuit Input (Private):**
```circom
signal private input r;              // Transaction secret key
signal private input amount;         // Transaction amount
signal private input lpViewKey;      // LP's private view key
signal private input merkleProof[];  // Merkle inclusion proof
```

**Circuit Output (Public):**
```circom
signal output R;                     // R = r·G (public key)
signal output commitment;            // Poseidon commitment
signal output merkleRoot;            // Blockchain state root
```

**Verification on-chain:**
```solidity
function mint(
    bytes calldata proof,
    bytes calldata publicSignals
) external {
    // Verify PLONK proof
    require(plonkVerifier.verify(proof, publicSignals));
    
    // Verify Ed25519 signature
    require(ed25519.verify(signature, message, publicKey));
    
    // Mint wXMR
    _mint(msg.sender, amount);
}
```

### Burning (zkTLS)

**RPC Call to Monero Node:**
```json
{
  "jsonrpc": "2.0",
  "method": "get_transactions",
  "params": {
    "txs_hashes": ["a1b2c3d4..."],
    "decode_as_json": true
  }
}
```

**zkTLS Proof Generation:**
```javascript
const proof = await client.zkFetch(moneroRpcNode + '/json_rpc', {
  method: 'POST',
  body: JSON.stringify(rpcRequest)
});

// Proof contains:
// - Transaction hash
// - Block height
// - Confirmations
// - Amount (encrypted in Monero, but visible in RPC response)
```

**Verification on-chain:**
```solidity
function completeBurn(
    uint256 burnId,
    bytes calldata zkTLSProof
) external {
    // Submit to MoneroTxResolver
    txResolver.submitProof(escrowId, zkTLSProof);
    
    // Verify proof and extract data
    require(txResolver.isConditionMet(escrowId));
    
    // Finalize burn
    _finalizeBurn(burnId);
}
```

## Privacy Analysis

### What Remains Private

**On Monero side:**
- ✅ Sender identity (ring signatures)
- ✅ Recipient identity (stealth addresses)
- ✅ Transaction amount (RingCT)
- ✅ Transaction graph (decoy outputs)

**On Ethereum side:**
- ✅ Which specific Monero UTXO was used (ZK circuit hides this)
- ✅ Transaction secret key `r` (never revealed)
- ✅ LP's view key (only used in circuit, not on-chain)

### What Becomes Public

**On Ethereum side:**
- ❌ User's Ethereum address (inherent to EVM)
- ❌ Amount of wXMR minted (ERC-20 transparency)
- ❌ Timing of mint/burn (blockchain timestamps)

**Trade-off:** Ethereum transparency vs Monero privacy
**Mitigation:** Use privacy tools on Ethereum side (Tornado Cash, etc.)

## Security Considerations

### ZK Circuit Security

**Trusted Setup:**
- PLONK requires trusted setup ceremony
- Use existing Ethereum ceremonies or run new one
- Multi-party computation for security

**Circuit Bugs:**
- Audit circuit logic carefully
- Test with known attack vectors
- Formal verification recommended

### zkTLS Security

**RPC Node Trust:**
- User can choose any Monero RPC node
- Multiple proofs from different nodes possible
- Decentralized verification

**Proof Replay:**
- Each proof identifier used only once
- Prevents double-spending
- Time-based expiration possible

### Economic Security

**LP Collateral:**
- 150% collateralization in wstETH
- Protects against LP misbehavior
- Liquidation if collateral drops

**Confirmation Requirements:**
- Configurable (e.g., 10 blocks)
- Prevents chain reorganization attacks
- Balance security vs UX

## Implementation Checklist

### Phase 1: ZK Circuit (Existing)
- [x] Circom circuit implementation
- [x] PLONK proof generation
- [x] On-chain verifier
- [x] Ed25519 library
- [x] Merkle proof verification

### Phase 2: zkTLS Integration (New)
- [x] Test zkFetch with Monero RPC
- [x] MoneroTxResolver contract
- [ ] Deploy to Unichain testnet
- [ ] Integrate with WrappedMonero
- [ ] End-to-end testing
- [ ] Gas optimization

### Phase 3: Production
- [ ] Security audit (circuit + contracts)
- [ ] Trusted setup ceremony
- [ ] Mainnet deployment
- [ ] LP onboarding
- [ ] User documentation

## Testing Strategy

### Test ZK Circuit
```bash
cd circuit/
# Compile circuit
circom monero_proof.circom --r1cs --wasm --sym

# Generate witness
node generate_witness.js

# Generate proof
snarkjs plonk prove

# Verify proof
snarkjs plonk verify
```

### Test zkTLS Integration
```bash
# Test Monero RPC connectivity
node scripts/testMoneroRPC.js

# Test transaction proof generation
node scripts/testMoneroTxProof.js

# Deploy MoneroTxResolver
forge script script/DeployMoneroTxResolver.s.sol --broadcast

# Test end-to-end burn flow
node scripts/testBurnWithZkTLS.js
```

### Integration Tests
```bash
# Test complete mint flow (ZK circuit)
npm run test:mint

# Test complete burn flow (zkTLS)
npm run test:burn

# Test LP operations
npm run test:lp

# Gas benchmarks
npm run test:gas
```

## Gas Costs

| Operation | Gas Cost | Notes |
|-----------|----------|-------|
| Mint (PLONK verify) | ~280k | ZK circuit verification |
| Burn request | ~50k | Lock wXMR |
| Burn complete (zkTLS) | ~250k | zkTLS proof verification |
| LP register | ~100k | Set up LP account |
| LP deposit collateral | ~80k | wstETH transfer |

**Total mint:** ~280k gas
**Total burn:** ~300k gas

## Comparison with Alternatives

### vs Centralized Bridge
| Feature | hookedMonero | Centralized |
|---------|--------------|-------------|
| Trust model | Trustless | Trusted custodian |
| Privacy | High (ZK) | Low (KYC) |
| Censorship resistance | High | Low |
| Gas cost | ~280k | ~50k |

### vs Other ZK Bridges
| Feature | hookedMonero | zkBridge |
|---------|--------------|----------|
| Monero support | Yes | No |
| Privacy preservation | Yes (ZK circuit) | Partial |
| Oracle dependency | No (zkTLS) | Yes |
| Circuit complexity | ~1,167 constraints | ~10k+ |

## Future Enhancements

### Short Term
1. **Multi-proof verification** - Require proofs from N RPC nodes
2. **Automated proof generation** - Browser extension
3. **Gas optimization** - Batch operations
4. **Price feed zkTLS** - Replace Pyth oracle

### Long Term
1. **Cross-chain expansion** - Support other EVM chains
2. **Privacy pools** - Mix wXMR on Ethereum side
3. **Atomic swaps** - Direct XMR ↔ ETH swaps
4. **Recursive proofs** - Compress multiple operations

## Resources

- **hookedMonero:** https://github.com/madschristensen99/hookedMonero
- **Circom:** https://docs.circom.io
- **PLONK:** https://eprint.iacr.org/2019/953
- **Reclaim Protocol:** https://reclaimprotocol.org
- **Monero RPC:** https://www.getmonero.org/resources/developer-guides/daemon-rpc.html

## Conclusion

**hookedMonero's innovation:** Privacy-preserving ZK circuit for minting

**zkTLS addition:** Trustless oracle replacement for burning

**Together:** Fully decentralized, privacy-preserving Monero bridge! 🎉

---

**Next Step:** Test the complete flow with real Monero transactions on testnet
