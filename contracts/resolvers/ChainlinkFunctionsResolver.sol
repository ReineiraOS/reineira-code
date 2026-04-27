// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IConditionResolver} from "../interfaces/IConditionResolver.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";

/// @title ChainlinkFunctionsResolver
/// @notice Condition resolver using Chainlink Functions for custom off-chain computation
/// @dev Allows escrows to be released based on results from off-chain API calls and computation
///      executed in a decentralized oracle network (DON)
///
/// ## How It Works
/// 1. Configure escrow with source code, subscription ID, and expected result
/// 2. Anyone can trigger the request to execute the off-chain computation
/// 3. Chainlink DON executes the code and returns the result
/// 4. If result matches expected value, condition is fulfilled
///
/// ## Use Cases
/// - Verify API responses (e.g., GitHub stars > 1000, Twitter followers > 10k)
/// - Fetch and compute data from multiple sources
/// - Access password-protected APIs with encrypted secrets
/// - Complex calculations that are expensive on-chain
///
/// ## Setup Requirements
/// 1. Create a Chainlink Functions subscription at https://functions.chain.link
/// 2. Fund subscription with LINK tokens
/// 3. Add this contract as a consumer to the subscription
/// 4. Configure escrow with your JavaScript source code
///
/// ## Supported Networks
/// See: https://docs.chain.link/chainlink-functions/supported-networks
/// Arbitrum Sepolia:
/// - Router: 0x234a5fb5Bd614a7AA2FfAB244D603abFA0Ac5C5C
contract ChainlinkFunctionsResolver is IConditionResolver, FunctionsClient, ERC165 {
    using FunctionsRequest for FunctionsRequest.Request;

    /// @notice Configuration for each escrow's Chainlink Functions condition
    struct Config {
        uint64 subscriptionId;
        uint32 gasLimit;
        bytes32 donId;
        bytes expectedResult;
        bool configured;
        bool fulfilled;
        bytes32 lastRequestId;
    }

    /// @custom:storage-location erc7201:reineira.storage.ChainlinkFunctionsResolver
    struct FunctionsStorage {
        mapping(uint256 => Config) configs;
        mapping(bytes32 => uint256) requestIdToEscrowId;
        mapping(uint256 => string) sources;
        mapping(uint256 => string[]) args;
        mapping(uint256 => bytes) encryptedSecretsUrls;
    }

    // keccak256(abi.encode(uint256(keccak256("reineira.storage.ChainlinkFunctionsResolver")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant FUNCTIONS_STORAGE_LOCATION =
        0x9f8e7d6c5b4a3f2e1d0c9b8a7f6e5d4c3b2a1f0e9d8c7b6a5f4e3d2c1b0a9f00;

    event ConditionConfigured(
        uint256 indexed escrowId, uint64 subscriptionId, bytes32 donId, uint32 gasLimit, bytes expectedResult
    );
    event RequestSent(uint256 indexed escrowId, bytes32 indexed requestId);
    event RequestFulfilled(uint256 indexed escrowId, bytes32 indexed requestId, bytes response, bytes err);
    event ConditionFulfilled(uint256 indexed escrowId, bytes result);

    error ConditionAlreadySet();
    error ConditionNotConfigured();
    error AlreadyFulfilled();
    error UnexpectedRequestId(bytes32 requestId);
    error ResultMismatch(bytes expected, bytes actual);
    error EmptySource();
    error InvalidSubscriptionId();

    constructor(address router) FunctionsClient(router) {}

    function _getFunctionsStorage() private pure returns (FunctionsStorage storage $) {
        assembly {
            $.slot := FUNCTIONS_STORAGE_LOCATION
        }
    }

    /// @notice Configure Chainlink Functions condition for an escrow
    /// @dev Data format: abi.encode(
    ///        string source,           // JavaScript source code to execute
    ///        string[] args,           // Arguments to pass to the source code
    ///        bytes encryptedSecretsUrls, // Encrypted secrets reference (optional)
    ///        uint64 subscriptionId,   // Chainlink Functions subscription ID
    ///        uint32 gasLimit,         // Gas limit for callback (default: 300000)
    ///        bytes32 donId,           // DON ID (e.g., 0x66756e2d617262697472756d2d7365706f6c69612d3100000000000000000000)
    ///        bytes expectedResult     // Expected result to fulfill condition
    ///      )
    /// @param escrowId The escrow identifier
    /// @param data ABI-encoded configuration
    function onConditionSet(uint256 escrowId, bytes calldata data) external {
        FunctionsStorage storage $ = _getFunctionsStorage();
        if ($.configs[escrowId].configured) revert ConditionAlreadySet();

        (
            string memory source,
            string[] memory args,
            bytes memory encryptedSecretsUrls,
            uint64 subscriptionId,
            uint32 gasLimit,
            bytes32 donId,
            bytes memory expectedResult
        ) = abi.decode(data, (string, string[], bytes, uint64, uint32, bytes32, bytes));

        if (bytes(source).length == 0) revert EmptySource();
        if (subscriptionId == 0) revert InvalidSubscriptionId();
        if (gasLimit == 0) gasLimit = 300000;

        $.configs[escrowId] = Config({
            subscriptionId: subscriptionId,
            gasLimit: gasLimit,
            donId: donId,
            expectedResult: expectedResult,
            configured: true,
            fulfilled: false,
            lastRequestId: bytes32(0)
        });

        $.sources[escrowId] = source;
        $.args[escrowId] = args;
        $.encryptedSecretsUrls[escrowId] = encryptedSecretsUrls;

        emit ConditionConfigured(escrowId, subscriptionId, donId, gasLimit, expectedResult);
    }

    /// @notice Execute the Chainlink Functions request for an escrow
    /// @dev Anyone can call this to trigger the off-chain computation
    /// @param escrowId The escrow identifier
    /// @return requestId The Chainlink Functions request ID
    function executeRequest(uint256 escrowId) external returns (bytes32 requestId) {
        FunctionsStorage storage $ = _getFunctionsStorage();
        Config storage config = $.configs[escrowId];

        if (!config.configured) revert ConditionNotConfigured();
        if (config.fulfilled) revert AlreadyFulfilled();

        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript($.sources[escrowId]);

        if ($.args[escrowId].length > 0) {
            req.setArgs($.args[escrowId]);
        }

        if ($.encryptedSecretsUrls[escrowId].length > 0) {
            req.addSecretsReference($.encryptedSecretsUrls[escrowId]);
        }

        requestId = _sendRequest(req.encodeCBOR(), config.subscriptionId, config.gasLimit, config.donId);

        $.requestIdToEscrowId[requestId] = escrowId;
        config.lastRequestId = requestId;

        emit RequestSent(escrowId, requestId);
    }

    /// @notice Callback function for Chainlink Functions to fulfill the request
    /// @dev Called by the Chainlink DON with the computation result
    /// @param requestId The request ID
    /// @param response The response from the DON
    /// @param err Any error from the DON
    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
        FunctionsStorage storage $ = _getFunctionsStorage();
        uint256 escrowId = $.requestIdToEscrowId[requestId];

        if (escrowId == 0) revert UnexpectedRequestId(requestId);

        Config storage config = $.configs[escrowId];

        emit RequestFulfilled(escrowId, requestId, response, err);

        if (err.length > 0) {
            return;
        }

        if (keccak256(response) == keccak256(config.expectedResult)) {
            config.fulfilled = true;
            emit ConditionFulfilled(escrowId, response);
        }
    }

    /// @notice Check if the condition is met
    /// @param escrowId The escrow identifier
    /// @return True if the Chainlink Functions result matches the expected value
    function isConditionMet(uint256 escrowId) external view returns (bool) {
        FunctionsStorage storage $ = _getFunctionsStorage();
        return $.configs[escrowId].fulfilled;
    }

    /// @notice Get the configuration for an escrow
    /// @param escrowId The escrow identifier
    /// @return config The escrow configuration
    function getConfig(uint256 escrowId) external view returns (Config memory config) {
        FunctionsStorage storage $ = _getFunctionsStorage();
        return $.configs[escrowId];
    }

    /// @notice Get the source code for an escrow
    /// @param escrowId The escrow identifier
    /// @return The JavaScript source code
    function getSource(uint256 escrowId) external view returns (string memory) {
        FunctionsStorage storage $ = _getFunctionsStorage();
        return $.sources[escrowId];
    }

    /// @notice Get the last request ID for an escrow
    /// @param escrowId The escrow identifier
    /// @return The last Chainlink Functions request ID
    function getLastRequestId(uint256 escrowId) external view returns (bytes32) {
        FunctionsStorage storage $ = _getFunctionsStorage();
        return $.configs[escrowId].lastRequestId;
    }

    /// @inheritdoc ERC165
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(IConditionResolver).interfaceId || super.supportsInterface(interfaceId);
    }
}
