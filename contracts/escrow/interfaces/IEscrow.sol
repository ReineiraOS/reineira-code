// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/// @title IEscrow
/// @notice Minimal interface for escrow contracts that accept ERC20 funding
interface IEscrow {
    /// @notice Fund an escrow with a given amount of tokens
    /// @param escrowId The ID of the escrow to fund
    /// @param amount The amount of tokens to fund
    function fund(uint256 escrowId, uint256 amount) external;
}
