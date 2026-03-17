Build a new IConditionResolver contract based on this description: $ARGUMENTS

Follow these steps exactly:

1. Create the Solidity contract in `contracts/resolvers/`. Name it based on the description (PascalCase + "Resolver").
2. Implement `IConditionResolver` from `contracts/interfaces/IConditionResolver.sol` and `ERC165` from OpenZeppelin.
3. Use the storage pattern from CLAUDE.md — mapping for per-escrow config, strict validation in `onConditionSet`, pure logic in `isConditionMet`.
4. If the resolver needs proof submission (zkTLS, external data), add a public `submitProof()` function with replay protection (`mapping(bytes32 => bool) usedProofs`).
5. Add NatSpec documentation to all public functions.
6. Create a matching test file in `test/resolvers/` using the resolver test pattern from CLAUDE.md. Include tests for: config storage, condition-not-met, condition-met, edge cases, and access control.
7. Verify against the security checklist in CLAUDE.md before presenting the result.

Solidity pragma: `^0.8.24`. Use custom errors over require strings. Emit events on state changes.
