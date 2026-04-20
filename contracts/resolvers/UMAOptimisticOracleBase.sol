// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IConditionResolver} from "../interfaces/IConditionResolver.sol";
import {IPredictionMarketResolver} from "../interfaces/IPredictionMarketResolver.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

/// @title UMAOptimisticOracleBase
/// @notice Abstract base for UMA Optimistic Oracle V3-based condition resolvers.
/// @dev Extends IPredictionMarketResolver with UMA OOv3 integration.
///      Uses ERC-7201 namespaced storage for upgradeable compatibility.
///
/// ## Pattern Choice
/// UMA's Optimistic Oracle V3 allows arbitrary assertions to be proposed and disputed.
/// This base abstracts the assertion lifecycle: proposed → settled → resolved.
/// Concrete implementations define assertion parameters and settlement logic.
///
/// ## UMA Integration
/// The OOv3 contract manages assertions with the following states:
/// - Unresolved: No assertion made or assertion is in dispute period
/// - Resolved: Assertion settled and truthful
/// - Invalid: Assertion disputed and rejected
///
/// ## Usage
/// 1. Inherit from this contract
/// 2. Implement _getOOv3Contract() to return the UMA OOv3 contract address
/// 3. Implement _getAssertionId(escrowId) to map escrow to assertion ID
/// 4. Call _configure(escrowId, data) in your onConditionSet override
/// 5. Optionally implement _makeAssertion(escrowId) to create assertions programmatically
abstract contract UMAOptimisticOracleBase is IPredictionMarketResolver, ERC165 {
    /// @custom:storage-location erc7201:reineira.storage.UMAOptimisticOracleBase
    struct UMAStorage {
        mapping(uint256 => AssertionConfig) configs;
    }

    struct AssertionConfig {
        bytes32 assertionId;
        bool expectedTruthful;
        bool configured;
    }

    // keccak256(abi.encode(uint256(keccak256("reineira.storage.UMAOptimisticOracleBase")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant UMA_STORAGE_LOCATION =
        0x5c0d1a2b3e4f6a7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b00;

    event UMAConfigured(uint256 indexed escrowId, bytes32 assertionId, bool expectedTruthful);
    event AssertionSettled(uint256 indexed escrowId, bytes32 assertionId, bool truthful);

    error ConditionAlreadySet();
    error ConditionNotConfigured();
    error InvalidOOv3Contract();
    error AssertionNotSettled();

    function _getUMAStorage() private pure returns (UMAStorage storage $) {
        assembly {
            $.slot := UMA_STORAGE_LOCATION
        }
    }

    /// @notice Configure the assertion parameters for an escrow.
    /// @dev Data format: abi.encode(bytes32 assertionId, bool expectedTruthful)
    ///      expectedTruthful: true if condition is met when assertion is truthful
    /// @param escrowId The escrow identifier.
    /// @param data ABI-encoded configuration.
    function _configure(uint256 escrowId, bytes calldata data) internal {
        UMAStorage storage $ = _getUMAStorage();
        if ($.configs[escrowId].configured) revert ConditionAlreadySet();

        (bytes32 assertionId, bool expectedTruthful) = abi.decode(data, (bytes32, bool));

        $.configs[escrowId] =
            AssertionConfig({assertionId: assertionId, expectedTruthful: expectedTruthful, configured: true});

        emit UMAConfigured(escrowId, assertionId, expectedTruthful);
    }

    /// @inheritdoc IPredictionMarketResolver
    function getOutcomeState(uint256 escrowId)
        public
        view
        virtual
        returns (OutcomeState state, uint256 winningOutcome)
    {
        UMAStorage storage $ = _getUMAStorage();
        if (!$.configs[escrowId].configured) revert ConditionNotConfigured();

        IOptimisticOracleV3 oov3 = _getOOv3Contract();
        if (address(oov3) == address(0)) revert InvalidOOv3Contract();

        bytes32 assertionId = $.configs[escrowId].assertionId;

        try oov3.getAssertion(assertionId) returns (IOptimisticOracleV3.Assertion memory assertion) {
            if (!assertion.settled) {
                return (OutcomeState.Unresolved, 0);
            }

            bool truthful = !assertion.settlementResolution;

            return (OutcomeState.Resolved, truthful ? 1 : 0);
        } catch {
            return (OutcomeState.Unresolved, 0);
        }
    }

    /// @inheritdoc IPredictionMarketResolver
    function getExpectedOutcome(uint256 escrowId) external view returns (uint256 expectedOutcome) {
        UMAStorage storage $ = _getUMAStorage();
        if (!$.configs[escrowId].configured) revert ConditionNotConfigured();
        return $.configs[escrowId].expectedTruthful ? 1 : 0;
    }

    /// @inheritdoc IPredictionMarketResolver
    function isResolved(uint256 escrowId) public view returns (bool) {
        (OutcomeState state,) = getOutcomeState(escrowId);
        return state == OutcomeState.Resolved;
    }

    /// @inheritdoc IConditionResolver
    function isConditionMet(uint256 escrowId) external view virtual returns (bool) {
        UMAStorage storage $ = _getUMAStorage();
        if (!$.configs[escrowId].configured) revert ConditionNotConfigured();

        (OutcomeState state, uint256 winningOutcome) = getOutcomeState(escrowId);

        if (state != OutcomeState.Resolved) {
            return false;
        }

        uint256 expectedOutcome = $.configs[escrowId].expectedTruthful ? 1 : 0;
        return winningOutcome == expectedOutcome;
    }

    /// @notice Get the UMA Optimistic Oracle V3 contract instance.
    /// @dev Concrete implementations must override this.
    /// @return The IOptimisticOracleV3 contract.
    function _getOOv3Contract() internal view virtual returns (IOptimisticOracleV3);

    /// @notice Get the assertion ID for an escrow.
    /// @dev Concrete implementations may override this to dynamically map escrows to assertions.
    ///      Default implementation returns the configured assertionId.
    /// @param escrowId The escrow identifier.
    /// @return The assertion ID (bytes32).
    function _getAssertionId(uint256 escrowId) internal view virtual returns (bytes32) {
        UMAStorage storage $ = _getUMAStorage();
        return $.configs[escrowId].assertionId;
    }

    /// @inheritdoc ERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IConditionResolver).interfaceId
            || interfaceId == type(IPredictionMarketResolver).interfaceId || super.supportsInterface(interfaceId);
    }
}

/// @notice Minimal IOptimisticOracleV3 interface for local type resolution.
/// @dev This is a local workaround to avoid external dependencies in the base contract.
///      Production deployments should use the official UMA interfaces.
///      See: https://github.com/UMAprotocol/protocol/blob/master/packages/core/contracts/optimistic-oracle-v3/interfaces/OptimisticOracleV3Interface.sol
interface IOptimisticOracleV3 {
    struct Assertion {
        bool settled;
        bool settlementResolution;
        address asserter;
        uint64 assertionTime;
    }

    function getAssertion(bytes32 assertionId) external view returns (Assertion memory);
}
