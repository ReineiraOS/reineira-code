// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IConditionResolver} from "../interfaces/IConditionResolver.sol";
import {IZkTLSVerifier} from "../interfaces/IZkTLSVerifier.sol";
import {ProofGuard} from "../libraries/ProofGuard.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

/// @title ZkPassConditionBase
/// @notice Abstract base for condition resolvers using zkTLS proofs.
/// @dev Extends IConditionResolver with zkTLS verification and replay protection.
///      Concrete implementations must define _validateCondition to interpret proof data.
///
/// ## Pattern Choice
/// This base uses ERC-7201 namespaced storage to prevent collisions in upgradeable contexts.
/// Storage layout is isolated per escrow via nested mappings, ensuring atomic initialization
/// during onConditionSet and preventing cross-escrow interference.
///
/// ## Usage
/// 1. Inherit from this contract
/// 2. Implement _validateCondition(escrowId, proof) to define your condition logic
/// 3. Call _configure(escrowId, data) in your onConditionSet override
/// 4. Optionally override _getMaxProofAge() to customize freshness requirements
abstract contract ZkPassConditionBase is IConditionResolver, ERC165 {
    /// @custom:storage-location erc7201:reineira.storage.ZkPassConditionBase
    struct ZkPassStorage {
        mapping(uint256 => EscrowConfig) configs;
        mapping(uint256 => mapping(bytes32 => bool)) consumedProofs;
    }

    struct EscrowConfig {
        address verifier;
        bytes32 expectedCommitment;
        uint256 maxProofAge;
        bool configured;
    }

    // keccak256(abi.encode(uint256(keccak256("reineira.storage.ZkPassConditionBase")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ZK_PASS_STORAGE_LOCATION =
        0x8f3e1b5c4d6a7f9e2b1c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f00;

    event ZkPassConfigured(uint256 indexed escrowId, address verifier, bytes32 expectedCommitment, uint256 maxProofAge);
    event ProofVerified(uint256 indexed escrowId, bytes32 proofHash, uint256 timestamp);

    error ConditionAlreadySet();
    error ConditionNotConfigured();
    error InvalidVerifier();
    error ProofVerificationFailed();
    error CommitmentMismatch(bytes32 expected, bytes32 actual);

    function _getZkPassStorage() private pure returns (ZkPassStorage storage $) {
        assembly {
            $.slot := ZK_PASS_STORAGE_LOCATION
        }
    }

    /// @notice Configure zkTLS verification for an escrow.
    /// @dev Called by concrete implementations during onConditionSet.
    ///      Data format: abi.encode(address verifier, bytes32 expectedCommitment, uint256 maxProofAge)
    /// @param escrowId The escrow identifier.
    /// @param data ABI-encoded configuration.
    function _configure(uint256 escrowId, bytes calldata data) internal {
        ZkPassStorage storage $ = _getZkPassStorage();
        if ($.configs[escrowId].configured) revert ConditionAlreadySet();

        (address verifier, bytes32 expectedCommitment, uint256 maxProofAge) =
            abi.decode(data, (address, bytes32, uint256));

        if (verifier == address(0)) revert InvalidVerifier();

        $.configs[escrowId] = EscrowConfig({
            verifier: verifier, expectedCommitment: expectedCommitment, maxProofAge: maxProofAge, configured: true
        });

        emit ZkPassConfigured(escrowId, verifier, expectedCommitment, maxProofAge);
    }

    /// @inheritdoc IConditionResolver
    function isConditionMet(uint256 escrowId) external view virtual returns (bool) {
        ZkPassStorage storage $ = _getZkPassStorage();
        if (!$.configs[escrowId].configured) revert ConditionNotConfigured();

        return _validateCondition(escrowId);
    }

    /// @notice Verify a zkTLS proof and mark it as consumed.
    /// @dev Called by concrete implementations to validate and consume proofs.
    ///      Ensures proof freshness, cryptographic validity, and replay protection.
    /// @param escrowId The escrow identifier.
    /// @param proof The zkTLS proof data.
    /// @param publicInputs Public inputs for verification.
    function _verifyAndConsumeProof(uint256 escrowId, bytes calldata proof, bytes calldata publicInputs) internal {
        ZkPassStorage storage $ = _getZkPassStorage();
        EscrowConfig storage config = $.configs[escrowId];

        if (!config.configured) revert ConditionNotConfigured();

        IZkTLSVerifier verifier = IZkTLSVerifier(config.verifier);

        uint256 timestamp = verifier.extractTimestamp(proof);
        ProofGuard.validateFreshness(timestamp, config.maxProofAge);

        bytes32 commitment = verifier.extractCommitment(proof);
        if (commitment != config.expectedCommitment) {
            revert CommitmentMismatch(config.expectedCommitment, commitment);
        }

        if (!verifier.verifyProof(proof, publicInputs)) {
            revert ProofVerificationFailed();
        }

        bytes32 proofHash = ProofGuard.hashProof(proof);
        ProofGuard.consume($.consumedProofs[escrowId], proofHash, escrowId);

        emit ProofVerified(escrowId, proofHash, timestamp);
    }

    /// @notice Check if a proof has been consumed for an escrow.
    /// @param escrowId The escrow identifier.
    /// @param proofHash The keccak256 hash of the proof.
    /// @return True if the proof has been used.
    function _isProofConsumed(uint256 escrowId, bytes32 proofHash) internal view returns (bool) {
        ZkPassStorage storage $ = _getZkPassStorage();
        return ProofGuard.isConsumed($.consumedProofs[escrowId], proofHash);
    }

    /// @notice Get the configuration for an escrow.
    /// @param escrowId The escrow identifier.
    /// @return config The escrow configuration.
    function _getConfig(uint256 escrowId) internal view returns (EscrowConfig memory config) {
        ZkPassStorage storage $ = _getZkPassStorage();
        return $.configs[escrowId];
    }

    /// @notice Validate the condition for an escrow.
    /// @dev Concrete implementations must override this to define condition logic.
    ///      This is called by isConditionMet and should return true when the condition is satisfied.
    /// @param escrowId The escrow identifier.
    /// @return True if the condition is met.
    function _validateCondition(uint256 escrowId) internal view virtual returns (bool);

    /// @inheritdoc ERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IConditionResolver).interfaceId || super.supportsInterface(interfaceId);
    }
}
