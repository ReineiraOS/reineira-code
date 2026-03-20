Generate a complete test file for this contract: $ARGUMENTS

Steps:

1. Read the contract source file specified in the argument.
2. Determine if it's a resolver (implements IConditionResolver) or policy (implements IUnderwriterPolicy).
3. Generate the test file in the appropriate directory (`test/resolvers/` or `test/policies/`).

For **resolvers**, generate tests for:

- Deployment succeeds
- `supportsInterface` returns true for IConditionResolver
- `onConditionSet` stores configuration correctly
- `onConditionSet` reverts on invalid input (test each validation)
- `isConditionMet` returns false before condition is met
- `isConditionMet` returns true after condition is met
- If proof-based: `submitProof` works with valid proof, reverts on replay, reverts on invalid proof

For **policies**, generate tests for:

- Deployment succeeds
- `supportsInterface` returns true for IUnderwriterPolicy
- `onPolicySet` stores configuration
- `evaluateRisk` returns without reverting (FHE — can't check plaintext value)
- `judge` returns without reverting with valid proof
- `judge` handles invalid proof gracefully
- Include `before()` hook with `hre.cofhe.initializeWithHardhatSigner(signer)`

Use the test patterns from CLAUDE.md. Include proper imports, loadFixture, and descriptive test names.
