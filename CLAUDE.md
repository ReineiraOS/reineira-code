# ReineiraOS Plugin Development Environment

You are building plugins for ReineiraOS — open settlement infrastructure on Arbitrum.
Plugins extend the protocol through two Solidity interfaces. This file is your complete reference.

## What this repo is

A Hardhat project for building and deploying:
- **Condition resolvers** — contracts that control when escrows release funds
- **Insurance policies** — contracts that evaluate risk and judge disputes using FHE

Builders describe what they want. You generate the contract, tests, and deployment.

## Project layout

```
contracts/
  interfaces/          — protocol interfaces (read-only reference)
  resolvers/           — IConditionResolver implementations (you create these)
  policies/            — IUnderwriterPolicy implementations (you create these)
test/
  resolvers/           — resolver test files
  policies/            — policy test files
scripts/
  deploy.ts            — universal deploy script
deployments/           — deployment records (auto-generated)
```

## The two plugin interfaces

### IConditionResolver — "When should this escrow release?"

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IConditionResolver {
    /// @notice Called on every redeem attempt. Return true to allow release.
    /// @dev Must be a view function. No state changes. Keep gas low.
    function isConditionMet(uint256 escrowId) external view returns (bool);

    /// @notice Called once at escrow creation. Parse and store configuration.
    /// @dev Called atomically during ConfidentialEscrow.create().
    function onConditionSet(uint256 escrowId, bytes calldata data) external;
}
```

**Rules for resolvers:**
- `isConditionMet` MUST be `view` — no state changes, no gas surprises
- `onConditionSet` runs once — validate inputs strictly, store config
- Support ERC-165: `supportsInterface(type(IConditionResolver).interfaceId)`
- One escrow ID → one condition state (replay protection)
- Keep `isConditionMet` gas under 50k — it's called on every redeem attempt

**Resolver storage pattern:**
```solidity
mapping(uint256 => YourConfigStruct) public configs;

function onConditionSet(uint256 escrowId, bytes calldata data) external {
    YourConfigStruct memory config = abi.decode(data, (YourConfigStruct));
    // validate config fields
    configs[escrowId] = config;
}

function isConditionMet(uint256 escrowId) external view returns (bool) {
    YourConfigStruct memory config = configs[escrowId];
    // evaluate condition against config
    return /* condition logic */;
}
```

### IUnderwriterPolicy — "How is risk evaluated? Is this dispute valid?"

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { euint64, ebool } from "@fhenixprotocol/cofhe-contracts/FHE.sol";

interface IUnderwriterPolicy {
    /// @notice Called when coverage is purchased. Store policy-specific data.
    function onPolicySet(uint256 coverageId, bytes calldata data) external;

    /// @notice Return an encrypted risk score (0-10000 basis points).
    /// @dev 100 bps = 1% premium. Score determines buyer's premium.
    function evaluateRisk(uint256 escrowId, bytes calldata riskProof)
        external returns (euint64 riskScore);

    /// @notice Judge a dispute. Return encrypted boolean (true = valid claim).
    function judge(uint256 coverageId, bytes calldata disputeProof)
        external returns (ebool valid);
}
```

**Rules for policies:**
- Return values MUST be FHE-encrypted (`euint64`, `ebool`)
- Always call `FHE.allowThis(value)` and `FHE.allow(value, msg.sender)` on return values
- Support ERC-165: `supportsInterface(type(IUnderwriterPolicy).interfaceId)`
- Risk score: 0-10000 basis points (100 = 1%, 500 = 5%, 1000 = 10%)
- `judge()` receives arbitrary proof bytes — decode and validate them

**FHE pattern (MUST follow exactly):**
```solidity
import { FHE, euint64, ebool } from "@fhenixprotocol/cofhe-contracts/FHE.sol";

function evaluateRisk(uint256, bytes calldata) external returns (euint64) {
    uint64 score = 500; // 5% premium
    euint64 encrypted = FHE.asEuint64(score);
    FHE.allowThis(encrypted);           // allow this contract to use value
    FHE.allow(encrypted, msg.sender);   // allow caller (protocol) to use value
    return encrypted;
}

function judge(uint256, bytes calldata) external returns (ebool) {
    bool isValid = true;
    ebool encrypted = FHE.asEbool(isValid);
    FHE.allowThis(encrypted);
    FHE.allow(encrypted, msg.sender);
    return encrypted;
}
```

## ERC-165 support (required for both)

```solidity
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

// For resolvers:
function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
    return interfaceId == type(IConditionResolver).interfaceId
        || super.supportsInterface(interfaceId);
}

// For policies:
function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
    return interfaceId == type(IUnderwriterPolicy).interfaceId
        || super.supportsInterface(interfaceId);
}
```

## Deployed contract addresses (Arbitrum Sepolia)

```
ConfidentialEscrow:        0xC4333F84F5034D8691CB95f068def2e3B6DC60Fa
CCTPV2EscrowReceiver:      0x48F2Ad7B9895683b865eaA5dfb852CB144895Eb7
SimpleCondition:           0x9817DA50DB5CE4316D2f0fF6bb6DBfe252C29593
PolicyRegistry:            0xf421363B642315BD3555dE2d9BD566b7f9213c8E
ConfidentialCoverageManager: 0x766e9508BD41BCE0e788F16Da86B3615386Ff6f6
PoolFactory:               0x03bAc36d45fA6f5aD8661b95D73452b3BedcaBFD
OperatorRegistry:          0x1422ccC8B42079D810835631a5DFE1347a602959
TaskExecutor:              0x7F24077A3341Af05E39fC232A77c21A03Bbd2262
FeeManager:                0x5a11DC96CEfd2fB46759F08aCE49515aa23F0156
CCTPHandler:               0xb37A83461B01097e1E440405264dA59EE9a3F273
ConfidentialUSDC (pUSDC):  0x6b6e6479b8b3237933c3ab9d8be969862d4ed89f
USDC:                      0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d
GovernanceToken:           0xb847e041bB3bC78C3CD951286AbCa28593739D12
TrustedForwarder:          0x7ceA357B5AC0639F89F9e378a1f03Aa5005C0a25

Chainlink ETH/USD feed:    0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612
Reclaim Verifier:          0xACE04E6DeB9567C1B8F37D113F2Da9E690Fc128d
UMA Optimistic Oracle V3:  0xa6B71E26C5e0845f74c812102Ca7114b6a896AB2
```

## Verification data sources for resolvers

Resolvers can verify any condition. Common patterns:

### zkTLS (Reclaim Protocol)
- Proves HTTPS endpoint returned expected data (PayPal, Stripe, bank APIs)
- Proof verified on-chain via Reclaim verifier at `0xACE04E6DeB9567C1B8F37D113F2Da9E690Fc128d`
- Pattern: buyer generates proof off-chain → submits to resolver → resolver verifies + marks fulfilled
- Storage: `mapping(uint256 => bool) public fulfilled` + `mapping(bytes32 => bool) public usedProofs`

### Oracle (Chainlink)
- Reads price feeds deployed natively on Arbitrum
- ETH/USD: `0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612` (8 decimals)
- `isConditionMet` calls `IChainlinkFeed.latestRoundData()` and checks threshold
- Always validate staleness: `require(block.timestamp - updatedAt <= maxStaleness)`
- Interface: `function latestRoundData() returns (uint80, int256 answer, uint256, uint256 updatedAt, uint80)`

### Prediction markets (UMA)
- Resolves binary or numeric outcomes via Optimistic Oracle
- UMA OO V3 on Arbitrum: `0xa6B71E26C5e0845f74c812102Ca7114b6a896AB2`
- `isConditionMet` calls `hasPrice()` then `getPrice()` and compares to required outcome
- Identifier: `bytes32` (e.g., `keccak256("YES_OR_NO_QUERY")`)
- Resolution values: `1e18` = YES, `0` = NO

### Multi-signature
- N-of-M approval pattern
- Storage: `mapping(uint256 => mapping(address => bool)) public approvals`
- `isConditionMet` counts approvals >= threshold
- `onConditionSet` stores signers array and threshold

### Time lock
- Simplest pattern: `block.timestamp >= deadline`
- `onConditionSet` stores deadline, validates it's in the future

## Testing patterns

### Resolver tests (no FHE needed)

```typescript
import hre from "hardhat";
import { expect } from "chai";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { time } from "@nomicfoundation/hardhat-network-helpers";

describe("MyResolver", function () {
  async function deployFixture() {
    const resolver = await hre.viem.deployContract("MyResolver");
    return { resolver };
  }

  it("should store config on onConditionSet", async function () {
    const { resolver } = await loadFixture(deployFixture);
    const data = hre.viem.encodePacked(/* your config encoding */);
    await resolver.write.onConditionSet([0n, data]);
    // assert stored state
  });

  it("should return false before condition met", async function () {
    const { resolver } = await loadFixture(deployFixture);
    expect(await resolver.read.isConditionMet([0n])).to.equal(false);
  });

  it("should return true after condition met", async function () {
    const { resolver } = await loadFixture(deployFixture);
    // trigger condition
    expect(await resolver.read.isConditionMet([0n])).to.equal(true);
  });
});
```

### Policy tests (FHE required)

```typescript
import hre from "hardhat";
import { ethers } from "hardhat";
import { expect } from "chai";

describe("MyPolicy", function () {
  before(async function () {
    // REQUIRED: initialize FHE mock backend
    const [signer] = await ethers.getSigners();
    await hre.cofhe.initializeWithHardhatSigner(signer);
  });

  it("should return encrypted risk score", async function () {
    const policy = await hre.viem.deployContract("MyPolicy");
    // evaluateRisk returns encrypted value — test that it doesn't revert
    await policy.write.evaluateRisk([0n, "0x"]);
  });

  it("should judge disputes", async function () {
    const policy = await hre.viem.deployContract("MyPolicy");
    const proof = ethers.AbiCoder.defaultAbiCoder().encode(
      ["bool", "uint256"],
      [true, Math.floor(Date.now() / 1000)]
    );
    await policy.write.judge([0n, proof]);
  });
});
```

### Time manipulation in tests

```typescript
import { time } from "@nomicfoundation/hardhat-network-helpers";

// Advance block timestamp
await time.increaseTo(deadline);

// Advance by duration
await time.increase(86400); // 1 day
```

### ABI encoding for resolver data

```typescript
import { ethers } from "hardhat";

// Encode single value
const data = ethers.AbiCoder.defaultAbiCoder().encode(
  ["uint256"],
  [deadline]
);

// Encode struct-like data
const data = ethers.AbiCoder.defaultAbiCoder().encode(
  ["address", "int256", "bool", "uint256"],
  [feedAddress, threshold, aboveOrBelow, maxStaleness]
);

// Encode string
const data = ethers.AbiCoder.defaultAbiCoder().encode(
  ["string"],
  ["MERCHANT_ID_123"]
);
```

## Deployment

Deploy any contract:
```bash
npx hardhat run scripts/deploy.ts --network arbitrumSepolia
```

The deploy script prompts for the contract name and saves to `deployments/arbitrumSepolia.json`.

Environment variables needed (see `.env.example`):
```
PRIVATE_KEY=0x...
ARBITRUM_SEPOLIA_RPC_URL=https://...
ETHERSCAN_API_KEY=...           # for contract verification
ESCROW_ADDRESS=0xC4333F84F5034D8691CB95f068def2e3B6DC60Fa
POLICY_REGISTRY_ADDRESS=0xf421363B642315BD3555dE2d9BD566b7f9213c8E
```

## SDK integration (attaching to escrow)

After deploying a resolver, attach it to an escrow via the SDK:

```typescript
import { ReineiraSDK } from "@reineira-os/sdk";

const sdk = ReineiraSDK.create({
  network: "testnet",
  privateKey: process.env.PRIVATE_KEY,
});
await sdk.initialize();

const resolverData = ethers.AbiCoder.defaultAbiCoder().encode(
  ["uint256"],   // your resolver's expected data format
  [1700000000]   // your resolver's config values
);

const escrow = await sdk.escrow.build()
  .amount(sdk.usdc(1000))
  .owner("0xRecipient...")
  .condition("0xYourDeployedResolver...", resolverData)
  .create();
```

## Security checklist

When reviewing generated contracts, verify:

- [ ] `isConditionMet` is `view` — no state changes
- [ ] `onConditionSet` validates all inputs (non-zero addresses, valid ranges, future deadlines)
- [ ] ERC-165 `supportsInterface` is implemented
- [ ] No reentrancy vectors in `onConditionSet` or `submitProof`
- [ ] Replay protection: proof hashes tracked, escrow IDs mapped 1:1
- [ ] External calls in `isConditionMet` use known contract addresses, not user-supplied
- [ ] Oracle data freshness validated (check `updatedAt` timestamps)
- [ ] FHE values always have `FHE.allowThis()` + `FHE.allow(value, msg.sender)` called
- [ ] No plaintext secrets stored on-chain
- [ ] Gas consumption of `isConditionMet` is bounded (no unbounded loops)

## Solidity conventions

- Pragma: `^0.8.24`
- License: `SPDX-License-Identifier: MIT`
- Compiler: solc 0.8.25, EVM target: cancun, optimizer: 200 runs
- Imports: use `@openzeppelin/contracts/` and `@fhenixprotocol/cofhe-contracts/`
- Error handling: use custom errors over require strings for gas efficiency
- Events: emit events on state changes in `onConditionSet` and proof submission
- NatSpec: document all public functions with `@notice` and `@param`

## Common mistakes to avoid

1. **Making `isConditionMet` non-view** — it must be `view`. State changes here will cause the protocol to revert.
2. **Forgetting FHE.allowThis()** — without this, the protocol can't read your encrypted return value. The transaction will succeed but the value will be unusable.
3. **Not validating `onConditionSet` inputs** — this runs once at escrow creation. If invalid data gets stored, the escrow is permanently broken.
4. **Trusting user-supplied addresses in view calls** — never call `IChainlinkFeed(userAddress).latestRoundData()` where `userAddress` comes from `resolverData`. Store the feed address in `onConditionSet` and validate it.
5. **No replay protection for proof-based resolvers** — if a proof can be submitted twice, the resolver is broken. Track `usedProofs[keccak256(proof)]`.
6. **Unbounded gas in `isConditionMet`** — this is called on every redeem attempt. Iterating over arrays or making multiple external calls can make redemption prohibitively expensive.
