Build a new IUnderwriterPolicy contract based on this description: $ARGUMENTS

Follow these steps exactly:

1. Create the Solidity contract in `contracts/policies/`. Name it based on the description (PascalCase + "Policy").
2. Implement `IUnderwriterPolicy` from `contracts/interfaces/IUnderwriterPolicy.sol` and `ERC165` from OpenZeppelin.
3. Import FHE: `import { FHE, euint64, ebool } from "@fhenixprotocol/cofhe-contracts/FHE.sol";`
4. `evaluateRisk` MUST return `euint64` — follow the FHE pattern from CLAUDE.md exactly. Always call `FHE.allowThis()` and `FHE.allow(value, msg.sender)`.
5. `judge` MUST return `ebool` — decode the dispute proof, evaluate the evidence, encrypt the verdict.
6. Design a tiered risk model with at least 3 tiers. Document the basis-point scale (100 bps = 1%).
7. Design dispute validation with at least 3 rules (e.g., time window, proof presence, proof validity).
8. Create a matching test file in `test/policies/` using the policy test pattern from CLAUDE.md. Include the FHE initialization in `before()`.
9. Verify against the security checklist in CLAUDE.md.

Solidity pragma: `^0.8.24`. Use custom errors. Emit events. Full NatSpec.
