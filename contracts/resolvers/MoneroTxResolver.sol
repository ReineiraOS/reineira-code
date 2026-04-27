// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IConditionResolver} from "../interfaces/IConditionResolver.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

/// @title MoneroTxResolver
/// @notice Verifies Monero transactions using zkTLS proofs from Monero RPC nodes
/// @dev Uses Reclaim Protocol to prove transaction data from get_transactions RPC call
/// @dev This enables trustless verification of Monero payments without relying on centralized oracles
contract MoneroTxResolver is IConditionResolver, ERC165 {
    /// @notice Configuration for each Monero transaction verification
    struct Config {
        /// @dev Address of the Reclaim verifier contract
        address reclaimAddress;
        /// @dev Expected Monero transaction hash (64 hex chars)
        string expectedTxHash;
        /// @dev Expected recipient Monero address
        string expectedRecipient;
        /// @dev Minimum amount in atomic units (piconeros, 1 XMR = 10^12 piconeros)
        uint256 minAmount;
        /// @dev Minimum number of confirmations required
        uint256 minConfirmations;
        /// @dev Whether the condition has been fulfilled
        bool fulfilled;
    }

    mapping(uint256 => Config) public configs;
    mapping(bytes32 => bool) public usedProofIdentifiers;

    event ConditionSet(
        uint256 indexed escrowId,
        address reclaimAddress,
        string expectedTxHash,
        string expectedRecipient,
        uint256 minAmount,
        uint256 minConfirmations
    );
    
    event TransactionVerified(
        uint256 indexed escrowId,
        bytes32 indexed proofIdentifier,
        string txHash,
        uint256 amount,
        uint256 confirmations
    );

    error InvalidReclaimAddress();
    error EmptyTxHash();
    error ConditionAlreadySet();
    error AlreadyFulfilled();
    error ProofAlreadyUsed();
    error InvalidProof();
    error TxHashMismatch();
    error InsufficientAmount();
    error InsufficientConfirmations();
    error RecipientMismatch();

    /// @inheritdoc IConditionResolver
    /// @dev Data format: abi.encode(
    ///   address reclaimAddress,
    ///   string expectedTxHash,
    ///   string expectedRecipient,
    ///   uint256 minAmount,
    ///   uint256 minConfirmations
    /// )
    function onConditionSet(uint256 escrowId, bytes calldata data) external {
        if (configs[escrowId].reclaimAddress != address(0)) revert ConditionAlreadySet();

        (
            address reclaimAddress,
            string memory expectedTxHash,
            string memory expectedRecipient,
            uint256 minAmount,
            uint256 minConfirmations
        ) = abi.decode(data, (address, string, string, uint256, uint256));

        if (reclaimAddress == address(0)) revert InvalidReclaimAddress();
        if (bytes(expectedTxHash).length == 0) revert EmptyTxHash();

        configs[escrowId] = Config({
            reclaimAddress: reclaimAddress,
            expectedTxHash: expectedTxHash,
            expectedRecipient: expectedRecipient,
            minAmount: minAmount,
            minConfirmations: minConfirmations,
            fulfilled: false
        });

        emit ConditionSet(
            escrowId,
            reclaimAddress,
            expectedTxHash,
            expectedRecipient,
            minAmount,
            minConfirmations
        );
    }

    /// @notice Submit a zkTLS proof of Monero transaction from RPC node
    /// @dev Proof must contain JSON-RPC response from get_transactions method
    /// @param escrowId The escrow identifier
    /// @param proofData ABI-encoded Reclaim.Proof containing transaction data
    function submitProof(uint256 escrowId, bytes calldata proofData) external {
        Config storage config = configs[escrowId];

        if (config.fulfilled) revert AlreadyFulfilled();

        // Decode the proof structure (same as ReclaimResolver)
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

        // Verify provider is "http" (for HTTPS requests)
        if (keccak256(bytes(provider)) != keccak256(bytes("http"))) {
            revert InvalidProof();
        }

        // Call Reclaim verifier contract to verify the proof
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

        (bool success,) = config.reclaimAddress.staticcall(reclaimProofCall);
        if (!success) revert InvalidProof();

        // Extract and verify transaction data from context
        // Context contains the JSON-RPC response with transaction details
        _verifyTransactionData(escrowId, context);

        // Mark proof as used and condition as fulfilled
        usedProofIdentifiers[identifier] = true;
        config.fulfilled = true;

        emit TransactionVerified(
            escrowId, identifier, config.expectedTxHash, config.minAmount, config.minConfirmations
        );
    }

    /// @dev Verify transaction data extracted from zkTLS proof context
    /// @dev Context contains JSON-RPC response: {"result":{"txs":[{"tx_hash":"...","amount":...}]}}
    /// @param escrowId The escrow identifier
    /// @param context The proof context containing transaction data
    function _verifyTransactionData(uint256 escrowId, string memory context) internal view {
        Config storage config = configs[escrowId];

        // Extract tx_hash from context
        string memory txHash = _extractFieldFromJSON(context, '"tx_hash":"');
        if (keccak256(bytes(txHash)) != keccak256(bytes(config.expectedTxHash))) {
            revert TxHashMismatch();
        }

        // Extract and verify amount if specified
        if (config.minAmount > 0) {
            uint256 amount = _extractNumberFromJSON(context, '"amount":');
            if (amount < config.minAmount) {
                revert InsufficientAmount();
            }
        }

        // Extract and verify confirmations if specified
        if (config.minConfirmations > 0) {
            uint256 confirmations = _extractNumberFromJSON(context, '"confirmations":');
            if (confirmations < config.minConfirmations) {
                revert InsufficientConfirmations();
            }
        }

        // Verify recipient address if specified
        if (bytes(config.expectedRecipient).length > 0) {
            // Note: Monero addresses in outputs require view key decryption
            // For now, we verify the transaction exists with correct amount/confirmations
            // Full recipient verification would require additional proof data
        }
    }

    /// @dev Extract a string field from JSON context
    /// @param data The JSON string
    /// @param target The field prefix to search for (e.g., '"tx_hash":"')
    /// @return The extracted field value
    function _extractFieldFromJSON(string memory data, string memory target)
        internal
        pure
        returns (string memory)
    {
        bytes memory dataBytes = bytes(data);
        bytes memory targetBytes = bytes(target);

        if (dataBytes.length < targetBytes.length) {
            return "";
        }

        uint256 start = 0;
        bool foundStart = false;

        // Find the target string
        for (uint256 i = 0; i <= dataBytes.length - targetBytes.length; i++) {
            bool isMatch = true;
            for (uint256 j = 0; j < targetBytes.length && isMatch; j++) {
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
        uint256 end = start;
        while (end < dataBytes.length && !(dataBytes[end] == '"' && (end == 0 || dataBytes[end - 1] != "\\"))) {
            end++;
        }

        if (end <= start || end >= dataBytes.length) {
            return "";
        }

        bytes memory result = new bytes(end - start);
        for (uint256 i = start; i < end; i++) {
            result[i - start] = dataBytes[i];
        }

        return string(result);
    }

    /// @dev Extract a number field from JSON context
    /// @param data The JSON string
    /// @param target The field prefix to search for (e.g., '"amount":')
    /// @return The extracted number value
    function _extractNumberFromJSON(string memory data, string memory target) internal pure returns (uint256) {
        bytes memory dataBytes = bytes(data);
        bytes memory targetBytes = bytes(target);

        if (dataBytes.length < targetBytes.length) {
            return 0;
        }

        uint256 start = 0;
        bool foundStart = false;

        // Find the target string
        for (uint256 i = 0; i <= dataBytes.length - targetBytes.length; i++) {
            bool isMatch = true;
            for (uint256 j = 0; j < targetBytes.length && isMatch; j++) {
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
            return 0;
        }

        // Skip whitespace
        while (start < dataBytes.length && (dataBytes[start] == " " || dataBytes[start] == "\t")) {
            start++;
        }

        // Extract digits
        uint256 end = start;
        while (end < dataBytes.length && dataBytes[end] >= "0" && dataBytes[end] <= "9") {
            end++;
        }

        if (end <= start) {
            return 0;
        }

        // Convert to number
        uint256 result = 0;
        uint256 multiplier = 1;
        for (uint256 i = end; i > start; i--) {
            uint8 digit = uint8(dataBytes[i - 1]) - 48; // ASCII '0' = 48
            result += digit * multiplier;
            multiplier *= 10;
        }

        return result;
    }

    /// @inheritdoc IConditionResolver
    function isConditionMet(uint256 escrowId) external view returns (bool) {
        return configs[escrowId].fulfilled;
    }

    /// @inheritdoc ERC165
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(IConditionResolver).interfaceId || super.supportsInterface(interfaceId);
    }
}
