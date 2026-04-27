// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IConditionResolver} from "../interfaces/IConditionResolver.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

/// @title ReclaimResolver
/// @notice zkTLS-based condition resolver using Reclaim Protocol
/// @dev Releases escrow when valid proof of HTTPS endpoint data is submitted via Reclaim Protocol
/// @dev Note: Uses interface-based integration to avoid pragma version conflicts with Reclaim SDK (0.8.4)
contract ReclaimResolver is IConditionResolver, ERC165 {
    /// @notice Configuration for each escrow's Reclaim condition
    struct Config {
        /// @dev Address of the deployed Reclaim verifier contract
        address reclaimAddress;
        /// @dev Expected provider string (e.g., "http" for HTTP provider)
        string expectedProvider;
        /// @dev Optional context address to verify (empty string to skip)
        string expectedContextAddress;
        /// @dev Optional context message to verify (empty string to skip)
        string expectedContextMessage;
        /// @dev Whether the condition has been fulfilled
        bool fulfilled;
    }

    mapping(uint256 => Config) public configs;
    mapping(bytes32 => bool) public usedProofIdentifiers;

    event ConditionSet(
        uint256 indexed escrowId,
        address reclaimAddress,
        string expectedProvider,
        string expectedContextAddress,
        string expectedContextMessage
    );
    event ProofSubmitted(uint256 indexed escrowId, bytes32 identifier);

    error InvalidReclaimAddress();
    error EmptyProvider();
    error ConditionAlreadySet();
    error AlreadyFulfilled();
    error ProofAlreadyUsed();
    error InvalidProof();
    error ProviderMismatch();
    error ContextAddressMismatch();
    error ContextMessageMismatch();

    /// @inheritdoc IConditionResolver
    /// @dev Data format: abi.encode(address reclaimAddress, string expectedProvider, string expectedContextAddress, string expectedContextMessage)
    function onConditionSet(uint256 escrowId, bytes calldata data) external {
        if (configs[escrowId].reclaimAddress != address(0)) revert ConditionAlreadySet();

        (
            address reclaimAddress,
            string memory expectedProvider,
            string memory expectedContextAddress,
            string memory expectedContextMessage
        ) = abi.decode(data, (address, string, string, string));

        if (reclaimAddress == address(0)) revert InvalidReclaimAddress();
        if (bytes(expectedProvider).length == 0) revert EmptyProvider();

        configs[escrowId] = Config({
            reclaimAddress: reclaimAddress,
            expectedProvider: expectedProvider,
            expectedContextAddress: expectedContextAddress,
            expectedContextMessage: expectedContextMessage,
            fulfilled: false
        });

        emit ConditionSet(
            escrowId,
            reclaimAddress,
            expectedProvider,
            expectedContextAddress,
            expectedContextMessage
        );
    }

    /// @notice Submit a Reclaim zkTLS proof to fulfill the condition
    /// @dev The proof must be ABI-encoded as per Reclaim.Proof structure
    /// @param escrowId The escrow identifier
    /// @param proofData ABI-encoded Reclaim.Proof (ClaimInfo + SignedClaim)
    function submitProof(uint256 escrowId, bytes calldata proofData) external {
        Config storage config = configs[escrowId];

        if (config.fulfilled) revert AlreadyFulfilled();

        // Decode the proof structure
        // Reclaim.Proof has: (ClaimInfo claimInfo, SignedClaim signedClaim)
        // ClaimInfo has: (string provider, string parameters, string context)
        // SignedClaim has: (CompleteClaimData claim, bytes[] signatures)
        // CompleteClaimData has: (bytes32 identifier, address owner, uint32 timestampS, uint32 epoch)
        
        (
            string memory provider,
            string memory parameters,
            string memory context,
            bytes32 identifier,
            address owner,
            uint32 timestampS,
            uint32 epoch,
            bytes[] memory signatures
        ) = abi.decode(proofData, (string, string, string, bytes32, address, uint32, uint32, bytes[]));

        // Check if proof identifier has been used
        if (usedProofIdentifiers[identifier]) revert ProofAlreadyUsed();

        // Verify provider matches
        if (keccak256(bytes(provider)) != keccak256(bytes(config.expectedProvider))) {
            revert ProviderMismatch();
        }

        // Verify context if specified
        if (bytes(config.expectedContextAddress).length > 0) {
            string memory contextAddress = _extractFieldFromContext(context, '"contextAddress":"');
            if (keccak256(bytes(contextAddress)) != keccak256(bytes(config.expectedContextAddress))) {
                revert ContextAddressMismatch();
            }
        }

        if (bytes(config.expectedContextMessage).length > 0) {
            string memory contextMessage = _extractFieldFromContext(context, '"contextMessage":"');
            if (keccak256(bytes(contextMessage)) != keccak256(bytes(config.expectedContextMessage))) {
                revert ContextMessageMismatch();
            }
        }

        // Call Reclaim verifier contract to verify the proof
        // The verifyProof function accepts individual parameters
        bytes memory reclaimProofCall = abi.encodeWithSignature(
            "verifyProof(string,string,string,bytes32,address,uint32,uint32,bytes[])",
            provider,
            parameters,
            context,
            identifier,
            owner,
            timestampS,
            epoch,
            signatures
        );

        (bool success, ) = config.reclaimAddress.staticcall(reclaimProofCall);
        if (!success) revert InvalidProof();

        // Mark proof as used and condition as fulfilled
        usedProofIdentifiers[identifier] = true;
        config.fulfilled = true;

        emit ProofSubmitted(escrowId, identifier);
    }

    /// @inheritdoc IConditionResolver
    function isConditionMet(uint256 escrowId) external view returns (bool) {
        return configs[escrowId].fulfilled;
    }

    /// @dev Extract a field from JSON-like context string
    /// @param data The context string
    /// @param target The field prefix to search for (e.g., '"contextAddress":"')
    /// @return The extracted field value
    function _extractFieldFromContext(
        string memory data,
        string memory target
    ) internal pure returns (string memory) {
        bytes memory dataBytes = bytes(data);
        bytes memory targetBytes = bytes(target);

        if (dataBytes.length < targetBytes.length) {
            return "";
        }

        uint start = 0;
        bool foundStart = false;

        // Find the target string
        for (uint i = 0; i <= dataBytes.length - targetBytes.length; i++) {
            bool isMatch = true;
            for (uint j = 0; j < targetBytes.length && isMatch; j++) {
                if (dataBytes[i + j] != targetBytes[j]) {
                    isMatch = false;
                }
            }
            if (isMatch) {
                start = i + targetBytes.length;
                foundStart = true;
                break;
            }
        }

        if (!foundStart) {
            return "";
        }

        // Find the closing quote
        uint end = start;
        while (end < dataBytes.length && !(dataBytes[end] == '"' && (end == 0 || dataBytes[end - 1] != "\\"))) {
            end++;
        }

        if (end <= start || end >= dataBytes.length) {
            return "";
        }

        bytes memory result = new bytes(end - start);
        for (uint i = start; i < end; i++) {
            result[i - start] = dataBytes[i];
        }

        return string(result);
    }

    /// @inheritdoc ERC165
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(IConditionResolver).interfaceId || super.supportsInterface(interfaceId);
    }
}
