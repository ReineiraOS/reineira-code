// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/// @title IConfidentialUSDCWrapper
/// @notice Interface for wrapping/unwrapping plain USDC into confidential USDC
interface IConfidentialUSDCWrapper {
    /// @notice Wrap plain USDC into confidential USDC
    /// @param amount Amount of plain USDC to wrap
    function wrap(uint64 amount) external;

    /// @notice Unwrap confidential USDC back into plain USDC
    /// @param amount Amount of confidential USDC to unwrap
    function unwrap(uint64 amount) external;
}
