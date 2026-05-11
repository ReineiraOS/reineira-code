# Audit Readiness Checklist

> Tracks disposition of every PRVD-33 finding per acceptance criteria in DEV-126.

## Legend

- ✅ Fixed — code merged, tests passing
- 🟡 Accepted — explicitly accepted with documented rationale
- ⏳ Pending — awaiting design discussion or auditor input
- 🔲 Not yet evaluated

---

## Phase 3 — Escrow

### Highs

| ID | Finding | Disposition | Rationale / PR |
|---|---|---|---|
| ESC-MN-01 | CCTP receivers leave funds stuck if downstream call reverts after `receiveMessage` succeeds | ✅ Fixed | Added `recover()` defense-in-depth to `CCTPV2EscrowReceiver` and `CCTPV2ConfidentialEscrowReceiver`; `recoverConfidentialUsdc()` for encrypted variant. 16 test scenarios pass. |

### Mediums

| ID | Finding | Disposition | Rationale / PR |
|---|---|---|---|
| ESC-MN-02 | Resolver = unbounded trusted code | ⏳ Pending | Architectural decision deferred to external auditor input (plugin governance: whitelist vs permissionless vs timelock). |
| ESC-MN-03 | `CCTPV2ReceiverLib.HOOK_DATA_OFFSET = 376` not independently verified | ⏳ Pending | Will be addressed in Phase 5 orchestration refactor; constant drift risk noted. |
| ESC-MN-04 | Fee-recipient revert DoSes redemption | ⏳ Pending | Design decision needed: pull-payment vs per-iteration try/catch. Insurance manager is privileged so blast radius is bounded. |
| ESC-MN-05 | `setConfidentialUsdc` does not revoke `setOperator` on previous wrapper | ⏳ Pending | Trivial fix; batch into pre-mainnet hardening PR once Medium design decisions are finalized. |
| ESC-MN-06 | `EscrowRedeemed` / `EscrowBatchRedeemed` emit unconditionally | ⏳ Pending | Rename to `RedeemAttempted` or emit only after decrypted success ack — design decision. |
| ESC-MN-07 | Owner does not receive `FHE.allow` on escrow creation | ⏳ Pending | Platform-mediated model vs `grantOwnerAccess(escrowId)` opt-in — architectural decision. |
| ESC-MN-08 | Insurance manager lacks retroactive `FHE.allow` | ⏳ Pending | Enforce manager-set-before-creation in deploy script, or add admin migration — ops decision. |

### Lows / Infos

| ID | Finding | Disposition | Rationale / PR |
|---|---|---|---|
| ESC-MN-12 | `EscrowBatchRedeemed` emits input array including skipped IDs | 🟡 Accepted | Minor indexer inconvenience; filtered list would increase gas. Documented in event specs. |
| ESC-MN-13 | `paidAmount` updates re-grant only `FHE.allowThis` | 🟡 Accepted | Fresh ciphertext per fund event is acceptable for privacy model; documented. |
| ESC-MN-15 | Gas profiling for `redeemMultiple` at MAX_BATCH_SIZE=20 | ⏳ Pending | Profiling scheduled before mainnet; tighten to 10 if Arbitrum block limit exceeded. |
| ESC-MN-17, 18 | Test coverage gaps (smoke-only, missing happy-path) | 🔲 Not yet evaluated | Punted to PRVD-33a backlog. |
| ESC-MN-19 | `Escrow.create` accepts `amount_ = 0` | 🟡 Accepted | Trivial fix; will batch into hardening PR opportunistically. |
| ESC-MN-20 | `EscrowFunded` event lacks amount field | 🟡 Accepted | Trivial fix; will batch into hardening PR opportunistically. |

---

## Phase 4 — Insurance

(Not yet populated.)

## Phase 5 — Orchestration

(Not yet populated.)

## Phase 6 — Tokens

(Not yet populated.)
