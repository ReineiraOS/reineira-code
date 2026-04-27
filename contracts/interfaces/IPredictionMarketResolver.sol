// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IConditionResolver} from "./IConditionResolver.sol";

/// @title IPredictionMarketResolver
/// @notice Extended interface for prediction market-based condition resolvers.
/// @dev Extends IConditionResolver with prediction market outcome resolution.
///      Supports binary and categorical markets from providers like Polymarket, UMA, etc.
interface IPredictionMarketResolver is IConditionResolver {
    /// @notice Market outcome states.
    enum OutcomeState {
        Unresolved,
        Resolved,
        Invalid
    }

    /// @notice Get the current state of a market outcome.
    /// @dev MUST be a view function.
    /// @param escrowId The escrow identifier.
    /// @return state The current outcome state.
    /// @return winningOutcome The winning outcome index (only valid if state == Resolved).
    function getOutcomeState(uint256 escrowId) external view returns (OutcomeState state, uint256 winningOutcome);

    /// @notice Get the expected outcome for an escrow to release.
    /// @dev The condition is met when the market resolves to this outcome.
    /// @param escrowId The escrow identifier.
    /// @return expectedOutcome The outcome index that triggers release.
    function getExpectedOutcome(uint256 escrowId) external view returns (uint256 expectedOutcome);

    /// @notice Check if the market has been resolved.
    /// @dev Convenience function to check if outcome state is Resolved.
    /// @param escrowId The escrow identifier.
    /// @return True if the market has been resolved.
    function isResolved(uint256 escrowId) external view returns (bool);
}
