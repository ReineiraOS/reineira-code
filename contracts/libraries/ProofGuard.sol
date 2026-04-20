// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ProofGuard
/// @notice Shared library for proof freshness validation and replay protection.
/// @dev Use this library in condition resolvers that accept cryptographic proofs
///      or oracle data to prevent stale data and replay attacks.
library ProofGuard {
    /// @notice Emitted when a proof is marked as consumed.
    /// @param proofHash The keccak256 hash of the proof data.
    /// @param escrowId The escrow identifier the proof was used for.
    event ProofConsumed(bytes32 indexed proofHash, uint256 indexed escrowId);

    error ProofTooOld(uint256 timestamp, uint256 maxAge);
    error ProofAlreadyUsed(bytes32 proofHash);
    error ProofNotYetValid(uint256 timestamp, uint256 currentTime);

    /// @notice Validate that a timestamp is within acceptable bounds.
    /// @dev Checks that the timestamp is not in the future and not older than maxAge.
    /// @param timestamp The timestamp to validate (unix seconds).
    /// @param maxAge Maximum age in seconds (e.g., 3600 for 1 hour).
    function validateFreshness(uint256 timestamp, uint256 maxAge) internal view {
        if (timestamp > block.timestamp) {
            revert ProofNotYetValid(timestamp, block.timestamp);
        }
        if (block.timestamp - timestamp > maxAge) {
            revert ProofTooOld(timestamp, maxAge);
        }
    }

    /// @notice Check if a proof has already been consumed.
    /// @dev Uses a mapping(bytes32 => bool) to track consumed proofs.
    /// @param consumed The storage mapping tracking consumed proofs.
    /// @param proofHash The keccak256 hash of the proof data.
    /// @return True if the proof has been used, false otherwise.
    function isConsumed(mapping(bytes32 => bool) storage consumed, bytes32 proofHash)
        internal
        view
        returns (bool)
    {
        return consumed[proofHash];
    }

    /// @notice Mark a proof as consumed and emit an event.
    /// @dev Reverts if the proof has already been consumed.
    /// @param consumed The storage mapping tracking consumed proofs.
    /// @param proofHash The keccak256 hash of the proof data.
    /// @param escrowId The escrow identifier for event logging.
    function consume(mapping(bytes32 => bool) storage consumed, bytes32 proofHash, uint256 escrowId) internal {
        if (consumed[proofHash]) {
            revert ProofAlreadyUsed(proofHash);
        }
        consumed[proofHash] = true;
        emit ProofConsumed(proofHash, escrowId);
    }

    /// @notice Compute a unique proof hash from arbitrary data.
    /// @dev Use this to generate proofHash for replay protection.
    /// @param data The proof data to hash.
    /// @return The keccak256 hash of the data.
    function hashProof(bytes memory data) internal pure returns (bytes32) {
        return keccak256(data);
    }

    /// @notice Validate freshness and mark proof as consumed in one call.
    /// @dev Convenience function combining validateFreshness and consume.
    /// @param consumed The storage mapping tracking consumed proofs.
    /// @param proofData The raw proof data.
    /// @param timestamp The timestamp embedded in the proof.
    /// @param maxAge Maximum acceptable age in seconds.
    /// @param escrowId The escrow identifier for event logging.
    function validateAndConsume(
        mapping(bytes32 => bool) storage consumed,
        bytes memory proofData,
        uint256 timestamp,
        uint256 maxAge,
        uint256 escrowId
    ) internal {
        validateFreshness(timestamp, maxAge);
        bytes32 proofHash = hashProof(proofData);
        consume(consumed, proofHash, escrowId);
    }
}
