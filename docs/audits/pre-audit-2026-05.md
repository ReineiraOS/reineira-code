# Pre-Audit Report 2026-05

## Phase 3 — Escrow Findings

### §4.3.M Escrow Medium/High Findings

#### ESC-MN-01 — CCTP receivers leave funds stuck if downstream call reverts (HIGH)

**Severity:** High  
**Status:** Remediated  
**Files:** `packages/escrow/contracts/receivers/CCTPV2EscrowReceiver.sol`, `packages/escrow/contracts/receivers/CCTPV2ConfidentialEscrowReceiver.sol`

**Description:**
CCTP V2 receivers call `cctpV2Transmitter.receiveMessage` to mint inbound USDC, then forward to `escrow.fund` (plain) or `confidentialUsdc.wrap` → `escrow.fundFrom` (confidential). The CCTP V2 nonce is consumed on first successful receipt. If any downstream call reverts after `receiveMessage` succeeds, the inbound USDC is trapped in the receiver contract with no retry path.

**Mitigation Applied:**
- Added owner-only `recover(IERC20 token, uint256 amount, address to)` to both `CCTPV2EscrowReceiver` and `CCTPV2ConfidentialEscrowReceiver`.
- Added owner-only `recoverConfidentialUsdc(uint64 amount, address to)` to `CCTPV2ConfidentialEscrowReceiver` for encrypted-balance recovery.
- Verified via Foundry tests covering success path, only-owner access, balance limits, and end-to-end stuck-fund recovery for both plain and confidential variants.

---

### §4.4 Follow-ups

(Reserved for Phase 4 — Insurance findings.)

### §4.5 Follow-ups

(Reserved for Phase 5 — Orchestration findings.)

### §4.6 Follow-ups

(Reserved for Phase 6 — Tokens findings.)
