// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/// @title ICCTPV2MessageTransmitter
/// @notice Minimal interface for Circle CCTP V2 MessageTransmitter
interface ICCTPV2MessageTransmitter {
    /// @notice Receive a message from CCTP V2
    /// @param message The CCTP message bytes
    /// @param attestation The attestation bytes
    /// @return success True if the message was successfully received
    function receiveMessage(bytes calldata message, bytes calldata attestation) external returns (bool success);
}
