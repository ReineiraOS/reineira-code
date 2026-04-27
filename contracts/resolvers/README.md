# Condition Resolver Architecture

This directory contains base abstractions for pluggable condition resolvers in the Reineira protocol. All resolvers implement the `IConditionResolver` interface with two core methods:

- `isConditionMet(escrowId)` - View function to check if release condition is satisfied
- `onConditionSet(escrowId, data)` - Called atomically during escrow creation to initialize resolver state

## Architecture Overview

### Base Interfaces

#### `IConditionResolver`
Core interface for all condition resolvers. Defines the contract between escrow system and release conditions.

#### `IZkTLSVerifier`
Interface for zero-knowledge TLS proof verification systems. Used by resolvers that require authenticated off-chain data (e.g., proving specific HTTP responses).

**Methods:**
- `verifyProof(proof, publicInputs)` - Cryptographic proof validation
- `extractTimestamp(proof)` - Extract proof timestamp for freshness checks
- `extractCommitment(proof)` - Extract data commitment hash

#### `IOracleConditionResolver`
Extended interface for oracle-based resolvers (Chainlink, UMA, etc.). Adds oracle-specific functionality:

**Methods:**
- `getLatestValue(escrowId)` - Fetch latest oracle value and timestamp
- `isStale(escrowId)` - Check if oracle data exceeds staleness threshold
- `getThreshold(escrowId)` - Get configured threshold and comparison operator

**Comparison Operators:**
- `GreaterThan`, `GreaterThanOrEqual`, `LessThan`, `LessThanOrEqual`, `Equal`, `NotEqual`

#### `IPredictionMarketResolver`
Extended interface for prediction market outcome resolvers (Polymarket, UMA OOv3).

**Methods:**
- `getOutcomeState(escrowId)` - Get market state (Unresolved, Resolved, Invalid) and winning outcome
- `getExpectedOutcome(escrowId)` - Get the outcome that triggers escrow release
- `isResolved(escrowId)` - Check if market has been resolved

### Abstract Base Contracts

#### `ZkPassConditionBase`
Abstract base for zkTLS proof-based resolvers.

**Features:**
- ERC-7201 namespaced storage (`reineira.storage.ZkPassConditionBase`)
- Proof freshness validation via `ProofGuard` library
- Replay protection with consumed proof tracking
- Commitment verification against expected values

**Storage:**
```solidity
struct EscrowConfig {
    address verifier;           // IZkTLSVerifier implementation
    bytes32 expectedCommitment; // Expected data commitment
    uint256 maxProofAge;        // Maximum proof age in seconds
    bool configured;
}
```

**Usage Pattern:**
1. Inherit from `ZkPassConditionBase`
2. Implement `_validateCondition(escrowId)` for your condition logic
3. Call `_configure(escrowId, data)` in `onConditionSet`
4. Use `_verifyAndConsumeProof(escrowId, proof, publicInputs)` to validate proofs

**Configuration Data Format:**
```solidity
abi.encode(
    address verifier,
    bytes32 expectedCommitment,
    uint256 maxProofAge
)
```

#### `ChainlinkConditionBase`
Abstract base for Chainlink Data Feed integration.

**Features:**
- ERC-7201 namespaced storage (`reineira.storage.ChainlinkConditionBase`)
- Staleness detection for oracle data
- Configurable threshold comparisons
- Local `AggregatorV3Interface` type definition

**Storage:**
```solidity
struct OracleConfig {
    int256 threshold;      // Target value for comparison
    ComparisonOp op;       // Comparison operator
    uint256 maxStaleness;  // Maximum data age in seconds
    bool configured;
}
```

**Usage Pattern:**
1. Inherit from `ChainlinkConditionBase`
2. Implement `_getAggregator(escrowId)` to return feed address
3. Call `_configure(escrowId, data)` in `onConditionSet`
4. Optionally override `_evaluateCondition(escrowId, value)` for custom logic

**Configuration Data Format:**
```solidity
abi.encode(
    int256 threshold,
    uint8 op,              // Cast to ComparisonOp enum
    uint256 maxStaleness
)
```

#### `PolymarketCTFBase`
Abstract base for Polymarket Conditional Token Framework (CTF) integration.

**Features:**
- ERC-7201 namespaced storage (`reineira.storage.PolymarketCTFBase`)
- Binary and categorical market support
- Outcome resolution via CTF payout numerators
- Local `IConditionalTokens` interface

**Storage:**
```solidity
struct MarketConfig {
    uint256 expectedOutcome; // Outcome index that triggers release
    bool configured;
}
```

**Usage Pattern:**
1. Inherit from `PolymarketCTFBase`
2. Implement `_getCTFContract()` to return CTF contract address
3. Implement `_getConditionId(escrowId)` to map escrow to CTF condition
4. Call `_configure(escrowId, data)` in `onConditionSet`
5. Override `_getOutcomeSlotCount(escrowId)` for categorical markets (default: 2)

**Configuration Data Format:**
```solidity
abi.encode(uint256 expectedOutcome)
```

**Outcome Encoding:**
- Binary markets: 0 = NO, 1 = YES
- Categorical markets: 0..N-1 indexed outcomes

#### `UMAOptimisticOracleBase`
Abstract base for UMA Optimistic Oracle V3 integration.

**Features:**
- ERC-7201 namespaced storage (`reineira.storage.UMAOptimisticOracleBase`)
- Assertion lifecycle tracking (proposed → settled → resolved)
- Truthfulness-based outcome resolution
- Local `IOptimisticOracleV3` interface

**Storage:**
```solidity
struct AssertionConfig {
    bytes32 assertionId;    // UMA assertion identifier
    bool expectedTruthful;  // True if release on truthful assertion
    bool configured;
}
```

**Usage Pattern:**
1. Inherit from `UMAOptimisticOracleBase`
2. Implement `_getOOv3Contract()` to return OOv3 contract address
3. Call `_configure(escrowId, data)` in `onConditionSet`
4. Optionally override `_getAssertionId(escrowId)` for dynamic mapping

**Configuration Data Format:**
```solidity
abi.encode(
    bytes32 assertionId,
    bool expectedTruthful
)
```

**Outcome Encoding:**
- 0 = Assertion rejected/disputed
- 1 = Assertion settled as truthful

### Shared Libraries

#### `ProofGuard`
Library for proof freshness validation and replay protection.

**Functions:**
- `validateFreshness(timestamp, maxAge)` - Ensure timestamp is not too old or in future
- `isConsumed(consumed, proofHash)` - Check if proof has been used
- `consume(consumed, proofHash, escrowId)` - Mark proof as consumed and emit event
- `hashProof(data)` - Compute keccak256 hash for replay protection
- `validateAndConsume(...)` - Combined freshness check and consumption

**Error Types:**
- `ProofTooOld(timestamp, maxAge)`
- `ProofAlreadyUsed(proofHash)`
- `ProofNotYetValid(timestamp, currentTime)`

## Design Patterns

### ERC-7201 Namespaced Storage

All abstract bases use ERC-7201 namespaced storage to prevent storage collisions in upgradeable contexts:

```solidity
/// @custom:storage-location erc7201:reineira.storage.ContractName
struct ContractStorage {
    mapping(uint256 => Config) configs;
}

bytes32 private constant STORAGE_LOCATION = 
    keccak256(abi.encode(uint256(keccak256("reineira.storage.ContractName")) - 1)) & ~bytes32(uint256(0xff));

function _getStorage() private pure returns (ContractStorage storage $) {
    assembly {
        $.slot := STORAGE_LOCATION
    }
}
```

### Atomic Initialization

All resolvers initialize state during `onConditionSet`, which is called atomically with escrow creation. This ensures:
- No race conditions between escrow creation and resolver setup
- Immutable condition parameters once escrow is created
- Single-transaction deployment for better UX

### Local Type Workarounds

External interfaces (Chainlink, CTF, UMA) are defined locally to avoid dependency management complexity:
- `AggregatorV3Interface` for Chainlink
- `IConditionalTokens` for Polymarket CTF
- `IOptimisticOracleV3` for UMA

Production deployments should verify these match official interfaces.

### View-Only Condition Checks

`isConditionMet` MUST be a view function to support:
- Gas-free condition checking from frontends
- Batch condition queries
- Integration with read-only systems

State-changing operations (e.g., proof consumption) happen in separate transactions.

## Solidity Compatibility

- **Pragma:** `^0.8.24`
- **EVM Version:** Cancun (per `foundry.toml`)
- **Dependencies:**
  - OpenZeppelin Contracts v5.x
  - Fhenix CoFHE Contracts (for policy system)

## Testing Recommendations

### Unit Tests
- Test each base contract with mock implementations
- Verify ERC-7201 storage isolation
- Test edge cases (stale data, replay attacks, invalid proofs)

### Integration Tests
- Test atomic initialization during escrow creation
- Verify cross-contract interactions (escrow ↔ resolver)
- Test with real oracle/market contracts on testnets

### Fuzzing
- Fuzz proof freshness boundaries
- Fuzz threshold comparisons with extreme values
- Fuzz outcome state transitions

## Security Considerations

### Replay Protection
All proof-based resolvers MUST use `ProofGuard.consume()` to prevent proof reuse across escrows.

### Staleness Checks
Oracle-based resolvers MUST validate data freshness to prevent stale data attacks.

### Reentrancy
While bases don't perform external calls in `isConditionMet`, concrete implementations should be cautious of reentrancy if they add state-changing logic.

### Access Control
Concrete implementations should consider:
- Who can call `onConditionSet`? (Should be restricted to escrow contract)
- Who can submit proofs/trigger updates?
- Should there be emergency pause mechanisms?

## Concrete Implementations

### ReclaimResolver (Production-Ready)

**Status:** ✅ Deployed and tested on Arbitrum Sepolia

A complete zkTLS-based resolver using Reclaim Protocol for verifying HTTP/HTTPS endpoint data.

**Contract:** `ReclaimResolver.sol`

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
- ReclaimResolver: `0x5f6F022740320c49F3F3868a75599d7fE0ac65c9`
- SimpleEscrow: `0x58eba8b9258907bE0BEeAD6F25D7EEfda9735ff0`
- ZkFetchVerifier (Mock): `0x4a0Bd08E23AdEE060CB3a45C38A01268C6753b4d`

**E2E Test:**
```bash
node scripts/zkFetchE2ETest.js
```

See main README for complete E2E test documentation.

## Out of Scope

This architecture provides **base abstractions** and **one production resolver** (ReclaimResolver). Additional concrete resolvers not yet included:
- TLSNotary-specific zkTLS resolver
- Chainlink feed-specific resolvers (ETH/USD, BTC/USD, etc.)
- Polymarket market-specific resolvers
- UMA assertion-specific resolvers

Developers should inherit from the base abstractions to create additional production resolvers.

## Future Extensions

Potential additions to the resolver ecosystem:
- Multi-condition resolvers (AND/OR logic)
- Time-bounded conditions (must resolve within X blocks)
- Upgradeable resolver proxies
- Resolver registries for discovery
- Cross-chain condition verification

## References

- [ERC-7201: Namespaced Storage Layout](https://eips.ethereum.org/EIPS/eip-7201)
- [Chainlink Data Feeds](https://docs.chain.link/data-feeds)
- [Gnosis Conditional Tokens](https://docs.gnosis.io/conditionaltokens/)
- [UMA Optimistic Oracle V3](https://docs.uma.xyz/developers/optimistic-oracle-v3)
- [zkTLS Overview](https://docs.tlsnotary.org/)
