// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {euint64, ebool} from "@fhenixprotocol/cofhe-contracts/FHE.sol";

/// @title IUnderwriterPolicy
/// @notice Interface for insurance policy plugins.
/// @dev Implement this to define risk evaluation and dispute resolution.
///      Return values are FHE-encrypted — the protocol operates on ciphertexts.
interface IUnderwriterPolicy {
  /// @notice Initialize policy-specific data for a new coverage.
  /// @param coverageId The coverage identifier.
  /// @param data ABI-encoded policy configuration.
  function onPolicySet(uint256 coverageId, bytes calldata data) external;

  /// @notice Evaluate risk and return an encrypted risk score.
  /// @dev Score is in basis points (0-10000). 100 bps = 1% premium.
  ///      MUST call FHE.allowThis() and FHE.allow(value, msg.sender) on return value.
  /// @param escrowId The escrow being insured.
  /// @param riskProof Arbitrary proof data for risk evaluation.
  /// @return riskScore Encrypted risk score in basis points.
  function evaluateRisk(uint256 escrowId, bytes calldata riskProof) external returns (euint64 riskScore);

  /// @notice Judge a dispute and return an encrypted verdict.
  /// @dev MUST call FHE.allowThis() and FHE.allow(value, msg.sender) on return value.
  /// @param coverageId The coverage being disputed.
  /// @param disputeProof Arbitrary proof data from the claimant.
  /// @return valid Encrypted boolean — true if the claim is legitimate.
  function judge(uint256 coverageId, bytes calldata disputeProof) external returns (ebool valid);
}
