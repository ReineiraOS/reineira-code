Generate SDK integration code for this deployed contract: $ARGUMENTS

The argument should include the contract name and deployed address. If not provided, check `deployments/arbitrumSepolia.json` for recent deployments.

Generate a complete TypeScript snippet showing:

1. **SDK initialization**:

```typescript
import { ReineiraSDK } from '@reineira-os/sdk';
const sdk = ReineiraSDK.create({ network: 'testnet', privateKey: process.env.PRIVATE_KEY });
await sdk.initialize();
```

2. **For resolvers** — create an escrow with this resolver attached:
   - Encode the resolver data using `ethers.AbiCoder.defaultAbiCoder().encode()` with the exact types the resolver's `onConditionSet` expects
   - Use `sdk.escrow.build().condition(address, data).create()`
   - Show how to check `isConditionMet` and call `redeem`

3. **For policies** — register the policy and purchase coverage:
   - Register: `sdk.insurance.registerPolicy(address)`
   - Add to pool: `pool.addPolicy(address)`
   - Purchase coverage: `sdk.insurance.purchaseCoverage({ pool, policy, escrowId, coverageAmount, expiry })`

4. **Event listening** — show how to listen for relevant events

Read the contract source to determine the exact `resolverData` encoding format from `onConditionSet`'s `abi.decode()` call.
