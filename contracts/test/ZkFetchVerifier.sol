// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ZkFetchVerifier
/// @notice Mock verifier for zkFetch proofs - accepts any proof for testing
/// @dev In production, zkFetch proofs should be verified off-chain using Reclaim SDK
///      This contract is ONLY for E2E testing purposes
contract ZkFetchVerifier {
    event ProofVerified(
        bytes32 indexed identifier,
        address indexed owner,
        string provider
    );

    /// @notice Verify a zkFetch proof (mock - always returns true)
    /// @dev In production, use Reclaim SDK's verifyProof() off-chain
    ///      This is a view function to work with staticcall from ReclaimResolver
    function verifyProof(
        string memory, // provider
        string memory, // parameters
        string memory, // context
        bytes32, // identifier
        address, // owner
        uint32, // timestampS
        uint32, // epoch
        bytes[] memory // signatures
    ) external pure {
        // Mock verification - always succeeds
        // For zkFetch, real verification happens off-chain via Reclaim SDK
        // This is just a placeholder to allow on-chain proof submission
        return;
    }
}
