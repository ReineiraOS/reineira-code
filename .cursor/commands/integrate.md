# SDK Integration

Generate SDK integration code for this deployed contract: $ARGUMENTS

The argument should include the contract name and deployed address. If not provided, check `deployments/arbitrumSepolia.json` for recent deployments.

## Process

1. Read the contract source to determine the exact `resolverData` encoding format from `onConditionSet`'s `abi.decode()` call.
2. Generate SDK initialization snippet.
3. For **resolvers** — create an escrow with this resolver attached:
   - Encode the resolver data using `ethers.AbiCoder.defaultAbiCoder().encode()` with exact types
   - Use `sdk.escrow.build().condition(address, data).create()`
   - Show how to check `isConditionMet` and call `redeem`
4. For **policies** — register and purchase coverage:
   - Register: `sdk.insurance.registerPolicy(address)`
   - Add to pool: `pool.addPolicy(address)`
   - Purchase coverage with escrowId, coverageAmount, expiry
5. Show event listening for relevant events.

## Acceptance Criteria

- [ ] Correct data encoding matching contract's `abi.decode`
- [ ] Complete SDK flow (init -> create/register -> verify)
- [ ] Event listening included

## Output

Return: complete TypeScript integration snippet ready to use.
