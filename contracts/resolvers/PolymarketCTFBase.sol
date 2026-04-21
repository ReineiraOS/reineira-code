// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IConditionResolver} from "../interfaces/IConditionResolver.sol";
import {IPredictionMarketResolver} from "../interfaces/IPredictionMarketResolver.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

/// @title PolymarketCTFBase
/// @notice Abstract base for Polymarket CTF (Conditional Token Framework) outcome resolvers.
/// @dev Extends IPredictionMarketResolver with Polymarket CTF integration.
///      Uses ERC-7201 namespaced storage for upgradeable compatibility.
///
/// ## Pattern Choice
/// Polymarket uses the Gnosis Conditional Token Framework (CTF) for binary and categorical markets.
/// This base abstracts the CTF interaction pattern, querying condition resolution from the CTF contract.
/// Concrete implementations provide the CTF contract address and condition ID mapping.
///
/// ## CTF Integration
/// The CTF contract resolves conditions to outcome slots. For binary markets:
/// - Outcome 0 = NO
/// - Outcome 1 = YES
/// For categorical markets, outcomes are indexed 0..N-1.
///
/// ## Usage
/// 1. Inherit from this contract
/// 2. Implement _getCTFContract() to return the CTF contract address
/// 3. Implement _getConditionId(escrowId) to map escrow to CTF condition ID
/// 4. Call _configure(escrowId, data) in your onConditionSet override
abstract contract PolymarketCTFBase is IPredictionMarketResolver, ERC165 {
    /// @custom:storage-location erc7201:reineira.storage.PolymarketCTFBase
    struct PolymarketStorage {
        mapping(uint256 => MarketConfig) configs;
    }

    struct MarketConfig {
        uint256 expectedOutcome;
        bool configured;
    }

    // keccak256(abi.encode(uint256(keccak256("reineira.storage.PolymarketCTFBase")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant POLYMARKET_STORAGE_LOCATION =
        0x6d1c0b3a4e5f7d8c9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e00;

    event PolymarketConfigured(uint256 indexed escrowId, uint256 expectedOutcome);

    error ConditionAlreadySet();
    error ConditionNotConfigured();
    error InvalidCTFContract();
    error ConditionNotResolved();

    function _getPolymarketStorage() private pure returns (PolymarketStorage storage $) {
        assembly {
            $.slot := POLYMARKET_STORAGE_LOCATION
        }
    }

    /// @notice Configure the expected outcome for an escrow.
    /// @dev Data format: abi.encode(uint256 expectedOutcome)
    ///      For binary markets: 0 = NO, 1 = YES
    /// @param escrowId The escrow identifier.
    /// @param data ABI-encoded configuration.
    function _configure(uint256 escrowId, bytes calldata data) internal {
        PolymarketStorage storage $ = _getPolymarketStorage();
        if ($.configs[escrowId].configured) revert ConditionAlreadySet();

        uint256 expectedOutcome = abi.decode(data, (uint256));

        $.configs[escrowId] = MarketConfig({expectedOutcome: expectedOutcome, configured: true});

        emit PolymarketConfigured(escrowId, expectedOutcome);
    }

    /// @inheritdoc IPredictionMarketResolver
    function getOutcomeState(uint256 escrowId)
        public
        view
        virtual
        returns (OutcomeState state, uint256 winningOutcome)
    {
        PolymarketStorage storage $ = _getPolymarketStorage();
        if (!$.configs[escrowId].configured) revert ConditionNotConfigured();

        IConditionalTokens ctf = _getCTFContract();
        if (address(ctf) == address(0)) revert InvalidCTFContract();

        bytes32 conditionId = _getConditionId(escrowId);

        uint256 payoutDenominator = ctf.payoutDenominator(conditionId);

        if (payoutDenominator == 0) {
            return (OutcomeState.Unresolved, 0);
        }

        uint256 outcomeSlotCount = _getOutcomeSlotCount(escrowId);
        for (uint256 i = 0; i < outcomeSlotCount; i++) {
            uint256 payout = ctf.payoutNumerators(conditionId, i);
            if (payout == payoutDenominator) {
                return (OutcomeState.Resolved, i);
            }
        }

        return (OutcomeState.Invalid, 0);
    }

    /// @inheritdoc IPredictionMarketResolver
    function getExpectedOutcome(uint256 escrowId) external view returns (uint256 expectedOutcome) {
        PolymarketStorage storage $ = _getPolymarketStorage();
        if (!$.configs[escrowId].configured) revert ConditionNotConfigured();
        return $.configs[escrowId].expectedOutcome;
    }

    /// @inheritdoc IPredictionMarketResolver
    function isResolved(uint256 escrowId) public view returns (bool) {
        (OutcomeState state,) = getOutcomeState(escrowId);
        return state == OutcomeState.Resolved;
    }

    /// @inheritdoc IConditionResolver
    function isConditionMet(uint256 escrowId) external view virtual returns (bool) {
        PolymarketStorage storage $ = _getPolymarketStorage();
        if (!$.configs[escrowId].configured) revert ConditionNotConfigured();

        (OutcomeState state, uint256 winningOutcome) = getOutcomeState(escrowId);

        if (state != OutcomeState.Resolved) {
            return false;
        }

        return winningOutcome == $.configs[escrowId].expectedOutcome;
    }

    /// @notice Get the CTF contract instance.
    /// @dev Concrete implementations must override this.
    /// @return The IConditionalTokens contract.
    function _getCTFContract() internal view virtual returns (IConditionalTokens);

    /// @notice Get the CTF condition ID for an escrow.
    /// @dev Concrete implementations must override this to map escrow to condition.
    /// @param escrowId The escrow identifier.
    /// @return The CTF condition ID (bytes32).
    function _getConditionId(uint256 escrowId) internal view virtual returns (bytes32);

    /// @notice Get the number of outcome slots for a condition.
    /// @dev Default is 2 for binary markets. Override for categorical markets.
    /// @return The number of outcome slots.
    function _getOutcomeSlotCount(
        uint256 /* escrowId */
    )
        internal
        view
        virtual
        returns (uint256)
    {
        return 2;
    }

    /// @inheritdoc ERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IConditionResolver).interfaceId
            || interfaceId == type(IPredictionMarketResolver).interfaceId || super.supportsInterface(interfaceId);
    }
}

/// @notice Minimal IConditionalTokens interface for local type resolution.
/// @dev This is a local workaround to avoid external dependencies in the base contract.
///      Production deployments should use the official Gnosis CTF interfaces.
///      See: https://github.com/gnosis/conditional-tokens-contracts
interface IConditionalTokens {
    function payoutNumerators(bytes32 conditionId, uint256 index) external view returns (uint256);
    function payoutDenominator(bytes32 conditionId) external view returns (uint256);
}
