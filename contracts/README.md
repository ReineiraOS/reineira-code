# Smart Contracts

Escrow system with multiple condition resolver implementations.

## Core Contracts

### Escrow
- **`test/SimpleEscrow.sol`** - Basic escrow contract for testing
  - Create escrows with custom resolvers
  - Release funds when conditions are met
  - Refund functionality

### Interfaces
- **`interfaces/IConditionResolver.sol`** - Base interface for all resolvers
- **`interfaces/IOracleConditionResolver.sol`** - Extended interface for oracle-based resolvers

## Resolvers

### Chainlink Data Feeds
- **`resolvers/ChainlinkPriceFeedResolver.sol`** - Price feed based conditions
  - Uses Chainlink price feeds (ETH/USD, BTC/USD, LINK/USD, etc.)
  - Supports multiple comparison operators (>, <, ==, >=, <=, !=)
  - Staleness protection

- **`resolvers/ChainlinkConditionBase.sol`** - Base contract for Chainlink conditions

### Chainlink Functions
- **`resolvers/ChainlinkFunctionsResolver.sol`** - DON-based custom computation
  - Execute JavaScript code via Chainlink DON
  - Support for encrypted secrets
  - Configurable gas limits and subscriptions

### Reclaim Protocol
- **`resolvers/ReclaimResolver.sol`** - zkTLS proof verification
  - Verify HTTPS API responses on-chain
  - Zero-knowledge TLS proofs
  - Context-based validation

### Other Resolvers
- **`resolvers/TimeLockResolver.sol`** - Time-based conditions
- **`resolvers/MultiConditionResolver.sol`** - Combine multiple conditions

## Architecture

```
SimpleEscrow
    ├── IConditionResolver (interface)
    │   ├── ChainlinkPriceFeedResolver
    │   ├── ChainlinkFunctionsResolver
    │   ├── ReclaimResolver
    │   └── TimeLockResolver
    └── MultiConditionResolver
```

## Deployed Contracts (Arbitrum Sepolia)

| Contract | Address | Verified |
|----------|---------|----------|
| SimpleEscrow | `0xAF4E10197Ed7b823c0ef2716431ADB69aB30Ce0D` | ✅ |
| ChainlinkPriceFeedResolver | `0x23D3A5984043E9bF04D796b65DF67a687163Ce65` | ✅ |
| ChainlinkFunctionsResolver | `0xEaec0247A15103845af146f8700826940A4B42A3` | ✅ |
| ReclaimResolver | `0xc7b41B0Ad8d0F561eDe27fC7C467c1BD8250e792` | ✅ |

## Usage Example

```solidity
// Create escrow with price feed condition
bytes memory resolverData = abi.encode(
    ETH_USD_FEED,           // feed address
    2000 * 10**8,           // threshold ($2000)
    ComparisonOp.GreaterThan,
    3600                    // max staleness (1 hour)
);

uint256 escrowId = escrow.createEscrow{value: 1 ether}(
    beneficiary,
    address(priceFeedResolver),
    resolverData
);

// Check and release
if (escrow.isConditionMet(escrowId)) {
    escrow.release(escrowId);
}
```

## Security

- All resolvers implement `IConditionResolver` interface
- Reentrancy protection on escrow contract
- Staleness checks for oracle data
- Access control for sensitive operations
