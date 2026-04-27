# hookedMonero Integration Status

## Current State

### ✅ Completed
1. **MoneroTxResolver Contract** - Fully tested (11/11 tests passing)
2. **Monero RPC Testing** - Verified zkFetch works with 5/5 Monero nodes
3. **Architecture Documentation** - Complete integration guide
4. **Foundry Infrastructure** - Ready for deployment

### ⏳ In Progress
1. **hookedMonero Deployment to Arbitrum Sepolia**
   - Mock wstETH: ✅ Deployed
   - PLONK Verifier: ✅ Deployed  
   - WrappedMonero: ❌ Blocked (requires Pyth oracle)

### 🔧 Next Steps

#### Option 1: Deploy Mock Pyth
Create a simple mock Pyth contract that returns fixed prices for testing.

#### Option 2: Modify WrappedMonero
Remove Pyth dependency and use zkTLS price feeds directly.

#### Option 3: Use Existing Deployment
The hookedMonero contracts are already deployed on Unichain Testnet:
- WrappedMonero: `0xFcF13C60bAd2d7a75435077C63a64D6a30e90C89`
- PlonkVerifier: `0xE95b1C8e857d7CF5B04d2C5cA617B2B436E0d031`
- MockWstETH: `0x2F1CeDd6251A6648E0571896452d59cBD1bFb856`

## Deployed Contracts (Arbitrum Sepolia)

### From reineira-code repo:
- **ReclaimResolver:** `0x5f6F022740320c49F3F3868a75599d7fE0ac65c9`
- **SimpleEscrow:** `0x58eba8b9258907bE0BEeAD6F25D7EEfda9735ff0`
- **ZkFetchVerifier (Mock):** `0x4a0Bd08E23AdEE060CB3a45C38A01268C6753b4d`

### From hookedMonero repo (partial):
- **Mock wstETH:** `0x9a4656DCc9b9c37b45D1Cb965e974cc3851F34E4`
- **PLONK Verifier:** `0xC8B98A68c2377E6a54CD418292d71Ce5adD172b3`
- **WrappedMonero:** Not yet deployed (blocked on Pyth)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    MINTING FLOW                             │
│              (Privacy via ZK Circuit)                       │
└─────────────────────────────────────────────────────────────┘
                         │
                         ↓
              User sends XMR to LP
                         │
                         ↓
          Generate PLONK proof (Circom)
          (Proves ownership without revealing r)
                         │
                         ↓
          Submit to WrappedMonero contract
                         │
                         ↓
               Mint HookedXMR ✅


┌─────────────────────────────────────────────────────────────┐
│                    BURNING FLOW                             │
│         (Trustless via zkTLS Oracle)                        │
└─────────────────────────────────────────────────────────────┘
                         │
                         ↓
          User requests burn (lock HookedXMR)
                         │
                         ↓
          LP sends XMR to user's address
                         │
                         ↓
       Generate zkTLS proof from Monero RPC
       (Proves transaction exists + amount)
                         │
                         ↓
       Submit to MoneroTxResolver contract
                         │
                         ↓
            Verify proof on-chain
                         │
                         ↓
           Finalize burn, release LP ✅
```

## Testing Plan

### 1. Test on Unichain Testnet (Existing Deployment)
- Use existing WrappedMonero deployment
- Test minting with ZK circuit
- Integrate MoneroTxResolver for burns
- Full E2E test

### 2. Deploy to Arbitrum Sepolia (After Pyth Fix)
- Deploy complete stack
- Test with zkTLS integration
- Compare gas costs

### 3. Frontend Integration
- Clone/create hookedMonero UI
- Add zkTLS proof generation
- Test complete user flow

## Files Created

### In reineira-code-427:
1. `contracts/resolvers/MoneroTxResolver.sol` - zkTLS transaction verifier
2. `test/MoneroTxResolver.t.sol` - Complete test suite (11/11 passing)
3. `scripts/testMoneroRPC.js` - RPC connectivity test
4. `scripts/testMoneroTxProof.js` - Transaction proof demo
5. `scripts/hookedMoneroE2E.js` - End-to-end test script
6. `HOOKED_MONERO_INTEGRATION.md` - Architecture guide
7. `HOOKED_MONERO_QUICKSTART.md` - Deployment guide

### In hookedMonero:
1. `hardhat.config.js` - Added Arbitrum Sepolia network
2. `scripts/deploy-arbitrum-simple.js` - Simplified deployment script

## Recommendations

### Immediate: Use Unichain Deployment
1. Test with existing Unichain deployment
2. Deploy MoneroTxResolver to Unichain
3. Build/test frontend integration
4. Validate complete flow

### Short-term: Fix Arbitrum Deployment
1. Create MockPyth contract
2. Deploy complete stack to Arbitrum Sepolia
3. Test zkTLS integration
4. Compare with Unichain

### Long-term: Production
1. Replace Pyth with zkTLS price feeds entirely
2. Audit all contracts
3. Deploy to mainnet
4. Launch UI

## Gas Costs (Estimated)

| Operation | Gas Cost | USD (@ 0.5 gwei, $2000 ETH) |
|-----------|----------|------------------------------|
| Mint (PLONK verify) | ~280k | ~$0.28 |
| Burn request | ~50k | ~$0.05 |
| Submit zkTLS proof | ~222k | ~$0.22 |
| Release escrow | ~50k | ~$0.05 |
| **Total round-trip** | **~602k** | **~$0.60** |

## Resources

- **reineira-code:** https://github.com/ReineiraOS/reineira-code (branch: hooked-monero-integration)
- **hookedMonero:** https://github.com/madschristensen99/hookedMonero
- **Reclaim Protocol:** https://reclaimprotocol.org
- **Monero RPC:** https://www.getmonero.org/resources/developer-guides/daemon-rpc.html

---

**Last Updated:** April 27, 2026
**Status:** Ready for testing on Unichain, blocked on Arbitrum (Pyth dependency)
