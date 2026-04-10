# Scaffold Test File

Generate a complete test file for this contract: $ARGUMENTS

## Process

1. Read the contract source file specified in the argument.
2. Determine if it's a resolver (implements IConditionResolver) or policy (implements IUnderwriterPolicy).
3. Generate the test file in the appropriate directory (`test/resolvers/` or `test/policies/`).

## Resolver Test Coverage

- Deployment succeeds
- `supportsInterface` returns true for IConditionResolver
- `onConditionSet` stores configuration correctly
- `onConditionSet` reverts on invalid input (test each validation)
- `isConditionMet` returns false before condition is met
- `isConditionMet` returns true after condition is met
- If proof-based: `submitProof` works with valid proof, reverts on replay, reverts on invalid proof

## Policy Test Coverage

- Deployment succeeds
- `supportsInterface` returns true for IUnderwriterPolicy
- `onPolicySet` stores configuration
- `evaluateRisk` returns without reverting (FHE — can't check plaintext value)
- `judge` returns without reverting with valid proof
- `judge` handles invalid proof gracefully
- Include `before()` hook with `hre.cofhe.initializeWithHardhatSigner(signer)`

## Acceptance Criteria

- [ ] Correct test directory (`test/resolvers/` or `test/policies/`)
- [ ] Uses `loadFixture` pattern
- [ ] Proper ABI encoding for test data
- [ ] All scenarios covered
- [ ] Tests pass: `npx hardhat test`

## Output

Return: complete test file ready to run.
