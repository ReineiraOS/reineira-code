// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IConditionResolver
/// @notice Interface for escrow release condition plugins.
/// @dev Implement this to control when a ConfidentialEscrow releases funds.
interface IConditionResolver {
  /// @notice Check if the release condition for an escrow is met.
  /// @dev Called on every redeem attempt. MUST be a view function.
  /// @param escrowId The sequential escrow identifier.
  /// @return True if the escrow should release funds.
  function isConditionMet(uint256 escrowId) external view returns (bool);

  /// @notice Initialize condition configuration for a new escrow.
  /// @dev Called atomically during ConfidentialEscrow.create().
  /// @param escrowId The sequential escrow identifier.
  /// @param data ABI-encoded configuration specific to this resolver.
  function onConditionSet(uint256 escrowId, bytes calldata data) external;
}
