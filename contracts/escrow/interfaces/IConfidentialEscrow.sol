// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/// @title IConfidentialEscrow
/// @notice Minimal interface for confidential escrow contracts
interface IConfidentialEscrow {
    /// @notice Fund an escrow from a specific address using confidential tokens
    /// @param escrowId The ID of the escrow to fund
    /// @param amount The amount of confidential tokens to fund
    /// @param from The address tokens are transferred from
    function fundFrom(uint256 escrowId, uint64 amount, address from) external;
}
