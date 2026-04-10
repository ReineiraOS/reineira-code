# Build Condition Resolver

Build a new IConditionResolver contract based on this description: $ARGUMENTS

## Process

1. Create the Solidity contract in `contracts/resolvers/`. Name it based on the description (PascalCase + "Resolver").
2. Implement `IConditionResolver` from `contracts/interfaces/IConditionResolver.sol` and `ERC165` from OpenZeppelin.
3. Use the storage pattern — mapping for per-escrow config, strict validation in `onConditionSet`, pure logic in `isConditionMet`.
4. If the resolver needs proof submission (zkTLS, external data), add a public `submitProof()` function with replay protection (`mapping(bytes32 => bool) usedProofs`).
5. Create a matching test file in `test/resolvers/` using the resolver test pattern. Include tests for: config storage, condition-not-met, condition-met, edge cases, and access control.
6. Verify against the security checklist before presenting the result.

## Acceptance Criteria

- [ ] Contract implements IConditionResolver + ERC165
- [ ] `isConditionMet` is `view` with gas < 50k
- [ ] `onConditionSet` validates all inputs
- [ ] Replay protection if proof-based
- [ ] Custom errors over require strings
- [ ] Events emitted on state changes
- [ ] Test file covers all scenarios
- [ ] Security checklist passes

## Output

Return: Solidity contract + test file, both ready to compile and run.
