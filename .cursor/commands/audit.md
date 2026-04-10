# Security Audit

Security audit this contract: $ARGUMENTS

## Process

Read the specified contract (or all contracts if none specified) and evaluate against every item:

1. **View safety**: Is `isConditionMet` a `view` function with no state changes?
2. **Input validation**: Does `onConditionSet` validate all inputs (non-zero, valid ranges, future deadlines)?
3. **ERC-165**: Is `supportsInterface` implemented correctly?
4. **Reentrancy**: Are there any reentrancy vectors in state-changing functions?
5. **Replay protection**: For proof-based resolvers, are proof hashes tracked?
6. **External call safety**: Do view functions use hardcoded known addresses, not user-supplied?
7. **Oracle freshness**: For oracle resolvers, is `updatedAt` checked against max staleness?
8. **FHE permissions**: Are `FHE.allowThis()` and `FHE.allow(value, msg.sender)` called on every encrypted return value?
9. **No plaintext secrets**: Is any sensitive data stored in plain text?
10. **Gas bounds**: Is `isConditionMet` gas consumption bounded? No unbounded loops?

Also check:
- Custom error usage (prefer over require strings)
- Event emission on state changes
- Storage efficiency (packed structs where possible)

## Acceptance Criteria

- [ ] All 10 items evaluated
- [ ] Each item: PASS, FAIL (with explanation), or N/A
- [ ] Fixes provided for any FAIL items

## Output

Return: audit report with per-item status and fixes for failures.
