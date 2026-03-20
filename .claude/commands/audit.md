Security audit this contract: $ARGUMENTS

Read the specified contract (or all contracts if none specified) and evaluate against every item in the CLAUDE.md security checklist:

1. **View safety**: Is `isConditionMet` a `view` function with no state changes?
2. **Input validation**: Does `onConditionSet` validate all inputs (non-zero, valid ranges, future deadlines)?
3. **ERC-165**: Is `supportsInterface` implemented correctly?
4. **Reentrancy**: Are there any reentrancy vectors in state-changing functions?
5. **Replay protection**: For proof-based resolvers, are proof hashes tracked?
6. **External call safety**: Do view functions use hardcoded known addresses, not user-supplied?
7. **Oracle freshness**: For oracle resolvers, is `updatedAt` checked against a max staleness?
8. **FHE permissions**: Are `FHE.allowThis()` and `FHE.allow(value, msg.sender)` called on every encrypted return value?
9. **No plaintext secrets**: Is any sensitive data stored in plain text?
10. **Gas bounds**: Is `isConditionMet` gas consumption bounded? No unbounded loops?

For each item, report: PASS, FAIL (with explanation), or N/A.

If any items FAIL, provide the specific fix with code.

Also check for:

- Custom error usage (prefer over require strings)
- NatSpec documentation completeness
- Event emission on state changes
- Storage efficiency (packed structs where possible)
