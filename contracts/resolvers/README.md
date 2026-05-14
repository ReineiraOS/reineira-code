# Condition Resolvers

This directory contains condition resolver implementations for the Reineira protocol. All resolvers implement the `IConditionResolver` interface with two core methods:

- `isConditionMet(escrowId)` - View function to check if release condition is satisfied
- `onConditionSet(escrowId, data)` - Called atomically during escrow creation to initialize resolver state

## Implementations

### ReclaimResolver

**Status:** ✅ Deployed and tested on Arbitrum Sepolia

A zkTLS-based resolver using Reclaim Protocol for verifying HTTP/HTTPS endpoint data.

**Features:**
- Verifies zkTLS proofs from Reclaim Protocol's zkFetch
- Supports provider validation (e.g., "http" for HTTP requests)
- Optional context validation (address and message fields)
- Replay protection via proof identifier tracking
- Interface-based integration to avoid pragma conflicts

**Storage:**
```solidity
struct Config {
    address reclaimAddress;           // Reclaim verifier contract
    string expectedProvider;          // Expected provider (e.g., "http")
    string expectedContextAddress;    // Optional context address
    string expectedContextMessage;    // Optional context message
    bool fulfilled;                   // Fulfillment status
}
```

**Configuration Data Format:**
```solidity
abi.encode(
    address reclaimAddress,
    string expectedProvider,
    string expectedContextAddress,    // Empty string to skip
    string expectedContextMessage     // Empty string to skip
)
```

**Usage Pattern:**
1. Deploy ReclaimResolver
2. Create escrow with resolver config pointing to Reclaim verifier
3. User generates zkTLS proof via Reclaim's zkFetch
4. User submits proof via `submitProof(escrowId, proofData)`
5. Resolver verifies proof and marks condition as met
6. Escrow can be released

**Proof Data Format:**
```solidity
abi.encode(
    string provider,
    string parameters,
    string context,
    bytes32 identifier,
    address owner,
    uint32 timestampS,
    uint32 epoch,
    bytes[] signatures
)
```

**Testnet Deployment (Arbitrum Sepolia):**
- ReclaimResolver: `0x05E856c5436Bd7b1f00a51f2D5154ea5b80f5D2c`
- SimpleEscrow: `0xd5F872B590AF61014A17DE9EA6Cd0c6f3208660b`
- ZkFetchVerifier (Mock): `0xB9b71f4c602a4cD82704eC329f535A0Ed916e138`

**E2E Test:**
```bash
node scripts/zkFetchE2ETest.js
```

**Transaction Examples:**
- Proof Submission: `0xa05dcff444422f2904e4eec15ff3a4e3a247e453884656795d192d7fc8d3d1b7`
- Escrow Release: `0x4ac738c50865813f83ee842b37d73897ee180c4bbec8fcfa269c008aaa0bfa7c`

### TimeLockResolver

A simple time-based resolver that releases escrow after a specified deadline.

**Features:**
- Releases funds after a configured timestamp
- Prevents setting deadlines in the past
- Single-use configuration per escrow

## Shared Libraries

### ProofGuard

Library for proof freshness validation and replay protection.

**Functions:**
- `validateFreshness(timestamp, maxAge)` - Ensure timestamp is not too old or in future
- `isConsumed(consumed, proofHash)` - Check if proof has been used
- `consume(consumed, proofHash, escrowId)` - Mark proof as consumed and emit event
- `hashProof(data)` - Compute keccak256 hash for replay protection
- `validateAndConsume(...)` - Combined freshness check and consumption

## Interfaces

### IConditionResolver

Core interface for all condition resolvers. Defines the contract between escrow system and release conditions.

### IZkTLSVerifier

Interface for zero-knowledge TLS proof verification systems. Used by resolvers that require authenticated off-chain data.

**Methods:**
- `verifyProof(proof, publicInputs)` - Cryptographic proof validation
- `extractTimestamp(proof)` - Extract proof timestamp for freshness checks
- `extractCommitment(proof)` - Extract data commitment hash

## Security Considerations

### Replay Protection
All proof-based resolvers MUST use `ProofGuard.consume()` to prevent proof reuse across escrows.

### Staleness Checks
Proof-based resolvers should validate data freshness to prevent stale data attacks.

### Access Control
Concrete implementations should consider:
- Who can call `onConditionSet`? (Should be restricted to escrow contract)
- Who can submit proofs/trigger updates?
- Should there be emergency pause mechanisms?

## References

- [Reclaim Protocol](https://www.reclaimprotocol.org/)
- [zkTLS Overview](https://docs.tlsnotary.org/)
- [ERC-7201: Namespaced Storage Layout](https://eips.ethereum.org/EIPS/eip-7201)
