# hookedMonero + zkTLS Quick Start

## Prerequisites

1. **Contracts deployed:**
   - MoneroTxResolver
   - ZkFetchVerifier (mock)
   - SimpleEscrow (for testing)

2. **Environment variables:**
   ```bash
   PRIVATE_KEY=0x...
   ARBITRUM_SEPOLIA_RPC_URL=https://sepolia-rollup.arbitrum.io/rpc
   RECLAIM_APP_ID=0x...
   RECLAIM_APP_SECRET=0x...
   ```

3. **Dependencies installed:**
   ```bash
   npm install
   ```

## Step 1: Deploy Contracts

```bash
# Deploy MoneroTxResolver
forge script script/DeployMoneroTxResolver.s.sol \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --broadcast \
  --legacy \
  --skip test --skip '*Policy*' \
  --with-gas-price 50000000

# Deploy ZkFetchVerifier (mock)
forge script script/DeployZkFetchE2E.s.sol \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --broadcast \
  --legacy \
  --skip test --skip '*Policy*' \
  --with-gas-price 50000000
```

**Save the deployed addresses to .env:**
```bash
MONERO_TX_RESOLVER=0x...
ZK_FETCH_VERIFIER=0x...
SIMPLE_ESCROW=0x...
```

## Step 2: Test Monero RPC Connectivity

```bash
# Test that zkFetch works with Monero nodes
node scripts/testMoneroRPC.js
```

**Expected output:**
```
✅ https://node.xmr.surf
✅ https://xmr.0xrpc.io
✅ https://xmr-node.cakewallet.com:18081
✅ https://kuk.fan
✅ https://monero.definitelynotafed.com

5/5 nodes succeeded
```

## Step 3: Run E2E Test

```bash
# Test complete burn flow with zkTLS
node scripts/hookedMoneroE2E.js
```

**Expected flow:**
1. ✅ Create burn request (escrow)
2. ✅ Generate zkTLS proof from Monero RPC
3. ✅ Verify proof cryptographically
4. ✅ Submit proof on-chain
5. ✅ MoneroTxResolver verifies proof
6. ✅ Burn completed successfully

## Step 4: Integrate with hookedMonero UI

### Clone hookedMonero

```bash
cd ..
git clone https://github.com/madschristensen99/hookedMonero.git
cd hookedMonero
npm install
```

### Update Contract Addresses

Edit `hookedMonero/src/config.ts`:

```typescript
export const CONTRACTS = {
  // Existing contracts
  wrappedMonero: '0x...',
  plonkVerifier: '0x...',
  
  // Add new contracts
  moneroTxResolver: '0x...', // From deployment
  zkFetchVerifier: '0x...',  // From deployment
};
```

### Add zkTLS Proof Generation

Create `hookedMonero/src/utils/zkTLSProof.ts`:

```typescript
import { ReclaimClient } from '@reclaimprotocol/zk-fetch';
import { verifyProof, transformForOnchain } from '@reclaimprotocol/js-sdk';

export async function generateMoneroTxProof(
  txHash: string,
  rpcNode: string = 'https://node.xmr.surf'
) {
  const client = new ReclaimClient(
    process.env.NEXT_PUBLIC_RECLAIM_APP_ID!,
    process.env.NEXT_PUBLIC_RECLAIM_APP_SECRET!
  );
  
  const rpcRequest = {
    jsonrpc: '2.0',
    id: '0',
    method: 'get_transactions',
    params: {
      txs_hashes: [txHash],
      decode_as_json: true
    }
  };
  
  const proof = await client.zkFetch(rpcNode + '/json_rpc', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(rpcRequest)
  });
  
  const { isVerified } = await verifyProof(proof, { 
    dangerouslyDisableContentValidation: true 
  });
  
  if (!isVerified) {
    throw new Error('Proof verification failed');
  }
  
  return transformForOnchain(proof);
}
```

### Update Burn Flow

Edit `hookedMonero/src/components/BurnFlow.tsx`:

```typescript
import { generateMoneroTxProof } from '../utils/zkTLSProof';
import { ethers } from 'ethers';

async function completeBurn(burnId: number, moneroTxHash: string) {
  // Generate zkTLS proof
  const { claimInfo, signedClaim } = await generateMoneroTxProof(moneroTxHash);
  
  // Encode proof
  const encodedProof = ethers.AbiCoder.defaultAbiCoder().encode(
    ['string', 'string', 'string', 'bytes32', 'address', 'uint32', 'uint32', 'bytes[]'],
    [
      claimInfo.provider,
      claimInfo.parameters,
      claimInfo.context,
      signedClaim.claim.identifier,
      signedClaim.claim.owner,
      signedClaim.claim.timestampS,
      signedClaim.claim.epoch,
      signedClaim.signatures
    ]
  );
  
  // Submit to MoneroTxResolver
  const tx = await wrappedMonero.completeBurn(burnId, encodedProof);
  await tx.wait();
}
```

### Add UI for Proof Generation

```tsx
<Button 
  onClick={async () => {
    setStatus('Generating zkTLS proof...');
    const proof = await generateMoneroTxProof(txHash);
    setStatus('Submitting proof on-chain...');
    await completeBurn(burnId, txHash);
    setStatus('Burn completed! ✅');
  }}
>
  Complete Burn with zkTLS Proof
</Button>
```

## Step 5: Test Complete Flow

### Minting (ZK Circuit - Existing)

1. Send XMR to LP's Monero address
2. Generate PLONK proof (browser)
3. Submit proof to WrappedMonero
4. Receive wXMR

### Burning (zkTLS - New!)

1. Request burn with Monero address
2. LP sends XMR to your address
3. **Generate zkTLS proof** (browser)
4. **Submit proof to MoneroTxResolver**
5. Burn finalized, LP gets collateral back

## Architecture Diagram

```
┌─────────────────────────────────────────────────┐
│              MINTING FLOW                       │
│         (Privacy via ZK Circuit)                │
└─────────────────────────────────────────────────┘
                      │
                      ↓
            User sends XMR to LP
                      │
                      ↓
         Generate PLONK proof in browser
         (Proves ownership without revealing r)
                      │
                      ↓
         Submit to WrappedMonero contract
                      │
                      ↓
              Mint wXMR ✅


┌─────────────────────────────────────────────────┐
│              BURNING FLOW                       │
│      (Trustless via zkTLS Oracle)               │
└─────────────────────────────────────────────────┘
                      │
                      ↓
         User requests burn (lock wXMR)
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

## Troubleshooting

### Proof Generation Fails

**Issue:** zkTLS proof generation times out

**Solution:**
- Try different Monero RPC node
- Check network connectivity
- Verify Reclaim credentials

### Proof Verification Fails

**Issue:** MoneroTxResolver rejects proof

**Solution:**
- Check tx hash matches expected
- Verify amount >= minimum
- Ensure confirmations >= threshold
- Check proof hasn't been used before

### Gas Estimation Fails

**Issue:** Transaction reverts during gas estimation

**Solution:**
- Increase gas limit manually
- Check contract addresses are correct
- Verify proof format is correct

## Gas Costs

| Operation | Gas Cost | USD (@ 0.5 gwei, $2000 ETH) |
|-----------|----------|------------------------------|
| Create burn request | ~50k | ~$0.05 |
| Submit zkTLS proof | ~250k | ~$0.25 |
| Release escrow | ~50k | ~$0.05 |
| **Total burn** | **~350k** | **~$0.35** |

Compare to:
- Trusted oracle: ~100k gas (~$0.10) but centralized
- No oracle: Free but requires trust

## Next Steps

1. ✅ Test on Arbitrum Sepolia
2. ⏳ Audit MoneroTxResolver contract
3. ⏳ Deploy to Unichain mainnet
4. ⏳ Integrate with production hookedMonero UI
5. ⏳ Launch fully decentralized Monero bridge!

## Resources

- **This repo:** https://github.com/ReineiraOS/reineira-code
- **hookedMonero:** https://github.com/madschristensen99/hookedMonero
- **Reclaim Protocol:** https://reclaimprotocol.org
- **Monero RPC:** https://www.getmonero.org/resources/developer-guides/daemon-rpc.html

---

**Ready to test?** Run `node scripts/hookedMoneroE2E.js` 🚀
