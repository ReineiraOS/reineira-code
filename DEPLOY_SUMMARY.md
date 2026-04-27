# hookedMonero + zkTLS Deployment Summary

## ✅ What's Working

### Arbitrum Sepolia (zkTLS Infrastructure)
All deployed and tested:

- **ReclaimResolver:** `0x5f6F022740320c49F3F3868a75599d7fE0ac65c9`
- **SimpleEscrow:** `0x58eba8b9258907bE0BEeAD6F25D7EEfda9735ff0`
- **ZkFetchVerifier (Mock):** `0x4a0Bd08E23AdEE060CB3a45C38A01268C6753b4d`
- **MoneroTxResolver:** Ready to deploy (11/11 tests passing)

### Unichain Testnet (hookedMonero Contracts)
Fully deployed and working:

- **WrappedMonero:** `0xFcF13C60bAd2d7a75435077C63a64D6a30e90C89`
- **PlonkVerifier:** `0xE95b1C8e857d7CF5B04d2C5cA617B2B436E0d031`
- **MockWstETH:** `0x2F1CeDd6251A6648E0571896452d59cBD1bFb856`
- **Pyth Oracle:** `0x2880aB155794e7179c9eE2e38200202908C17B43`

## 🎯 Recommended Path Forward

### Option 1: Deploy to Unichain (RECOMMENDED)
Use the existing working deployment on Unichain:

1. **Deploy MoneroTxResolver to Unichain**
   ```bash
   cd /home/remsee/reineira-code-427
   forge script script/DeployMoneroTxResolver.s.sol \
     --rpc-url https://sepolia.unichain.org \
     --broadcast \
     --legacy
   ```

2. **Test Complete Flow on Unichain**
   - Minting: Use existing ZK circuit
   - Burning: Use new MoneroTxResolver with zkTLS
   - Full E2E test

3. **Build/Deploy Frontend**
   - Integrate with Unichain deployment
   - Add zkTLS proof generation for burns
   - Test complete user flow

### Option 2: Fix Arbitrum Deployment
The issue is `_initializePrices()` in constructor fails because Pyth price feeds aren't initialized:

**Solutions:**
1. Update Pyth prices before deploying WrappedMonero
2. Modify constructor to skip price initialization
3. Use try/catch in `_initializePrices()`

## 📊 Test Results

### MoneroTxResolver Tests
```
✅ test_OnConditionSet
✅ test_RevertIf_ConditionAlreadySet  
✅ test_RevertIf_InvalidReclaimAddress
✅ test_RevertIf_EmptyTxHash
✅ test_SubmitProof_Success
✅ test_RevertIf_AlreadyFulfilled
✅ test_RevertIf_ProofAlreadyUsed
✅ test_RevertIf_InvalidProof
✅ test_RevertIf_TxHashMismatch
✅ test_SupportsInterface
✅ test_IsConditionMet_InitiallyFalse

11/11 tests passing
```

### Monero RPC Tests
```
✅ https://node.xmr.surf
✅ https://xmr.0xrpc.io
✅ https://xmr-node.cakewallet.com:18081
✅ https://kuk.fan
✅ https://monero.definitelynotafed.com

5/5 nodes succeeded
Block height verified: 3,661,851
```

## 🚀 Next Steps

### Immediate (Use Unichain)
1. Deploy MoneroTxResolver to Unichain
2. Update hookedMonero to integrate MoneroTxResolver for burns
3. Test minting flow (existing ZK circuit)
4. Test burning flow (new zkTLS)
5. Deploy frontend

### Short-term
1. Fix Arbitrum deployment (Pyth price initialization)
2. Deploy complete stack to Arbitrum Sepolia
3. Compare gas costs between chains

### Long-term
1. Replace Pyth entirely with zkTLS price feeds
2. Audit contracts
3. Mainnet deployment

## 📝 Commands

### Deploy MoneroTxResolver to Unichain
```bash
cd /home/remsee/reineira-code-427

# Add Unichain to foundry.toml
# Then deploy
forge script script/DeployMoneroTxResolver.s.sol \
  --rpc-url https://sepolia.unichain.org \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --legacy
```

### Test E2E on Unichain
```bash
# Update contract addresses in .env
MONERO_TX_RESOLVER=<deployed_address>
UNICHAIN_RPC_URL=https://sepolia.unichain.org

# Run E2E test
node scripts/hookedMoneroE2E.js
```

### Run hookedMonero Locally
```bash
cd /home/remsee/hookedMonero

# Compile circuit (if needed)
cd circuit && ./compile.sh

# Generate proof
cd ../scripts/proofGeneration
node generate_proof_and_mint.js

# Test burn with zkTLS
node ../burn_with_zktls.js
```

## 🔗 Resources

- **reineira-code:** `/home/remsee/reineira-code-427` (branch: hooked-monero-integration)
- **hookedMonero:** `/home/remsee/hookedMonero`
- **Unichain Explorer:** https://sepolia.uniscan.xyz
- **Arbitrum Sepolia Explorer:** https://sepolia.arbiscan.io

---

**Status:** Ready to deploy MoneroTxResolver to Unichain and test complete flow
**Blocker:** Arbitrum deployment needs Pyth price initialization fix
**Recommendation:** Use Unichain for initial testing, fix Arbitrum later
