# Run Tests

Run tests and fix any failures: $ARGUMENTS

## Process

1. If a specific test file or contract is mentioned, run only that: `npx hardhat test test/resolvers/<file>` or `test/policies/<file>`.
2. If no argument, run all tests: `npx hardhat test`
3. If tests fail:
   - Read the error output carefully
   - Identify whether the failure is in contract logic, test setup, or FHE initialization
   - For FHE-related failures: ensure `hre.cofhe.initializeWithHardhatSigner(signer)` is called in `before()`
   - For revert errors: check the contract's require/revert conditions match test expectations
   - Fix the issue and re-run
4. After all tests pass, report results summary.

## Common Issues

- FHE tests need `cofhe-hardhat-plugin` initialized — always use `before()` hook
- Time-dependent tests need `time.increaseTo()` or `time.increase()`
- Encoding test data: use `ethers.AbiCoder.defaultAbiCoder().encode()`

## Acceptance Criteria

- [ ] All tests pass
- [ ] Any failures diagnosed and fixed
- [ ] Results summary provided

## Output

Return: test results summary (pass/fail count).
