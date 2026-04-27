// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IConditionResolver} from "../interfaces/IConditionResolver.sol";
import {IOracleConditionResolver} from "../interfaces/IOracleConditionResolver.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @title ChainlinkConditionBase
/// @notice Abstract base for Chainlink oracle-based condition resolvers.
/// @dev Extends IOracleConditionResolver with Chainlink Data Feed integration.
///      Uses ERC-7201 namespaced storage for upgradeable compatibility.
///
/// ## Pattern Choice
/// This base abstracts the Chainlink AggregatorV3Interface interaction pattern,
/// providing staleness checks, decimal handling, and threshold comparisons.
/// Concrete implementations define the specific feed addresses and condition logic.
///
/// ## Usage
/// 1. Inherit from this contract
/// 2. Implement _getAggregator(escrowId) to return the Chainlink feed address
/// 3. Call _configure(escrowId, data) in your onConditionSet override
/// 4. Optionally override _evaluateCondition for custom comparison logic
///
/// ## Chainlink Integration
/// This contract expects Chainlink AggregatorV3Interface. For local testing,
/// you may need to deploy mock aggregators or use Chainlink's test feeds.
abstract contract ChainlinkConditionBase is IOracleConditionResolver, ERC165 {
    /// @custom:storage-location erc7201:reineira.storage.ChainlinkConditionBase
    struct ChainlinkStorage {
        mapping(uint256 => OracleConfig) configs;
    }

    struct OracleConfig {
        int256 threshold;
        ComparisonOp op;
        uint256 maxStaleness;
        bool configured;
    }

    // keccak256(abi.encode(uint256(keccak256("reineira.storage.ChainlinkConditionBase")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant CHAINLINK_STORAGE_LOCATION =
        0x7e2d0a4b3c5f6e8d9a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e00;

    event ChainlinkConfigured(uint256 indexed escrowId, int256 threshold, ComparisonOp op, uint256 maxStaleness);

    error ConditionAlreadySet();
    error ConditionNotConfigured();
    error StaleOracleData(uint256 lastUpdate, uint256 maxStaleness);
    error InvalidAggregator();
    error InvalidRoundData();

    function _getChainlinkStorage() private pure returns (ChainlinkStorage storage $) {
        assembly {
            $.slot := CHAINLINK_STORAGE_LOCATION
        }
    }

    /// @notice Configure oracle parameters for an escrow.
    /// @dev Data format: abi.encode(int256 threshold, uint8 op, uint256 maxStaleness)
    ///      maxStaleness is in seconds (e.g., 3600 for 1 hour).
    /// @param escrowId The escrow identifier.
    /// @param data ABI-encoded configuration.
    function _configure(uint256 escrowId, bytes memory data) internal {
        ChainlinkStorage storage $ = _getChainlinkStorage();
        if ($.configs[escrowId].configured) revert ConditionAlreadySet();

        (int256 threshold, uint8 opRaw, uint256 maxStaleness) = abi.decode(data, (int256, uint8, uint256));

        require(opRaw <= uint8(ComparisonOp.NotEqual), "Invalid comparison operator");
        ComparisonOp op = ComparisonOp(opRaw);

        $.configs[escrowId] = OracleConfig({threshold: threshold, op: op, maxStaleness: maxStaleness, configured: true});

        emit ChainlinkConfigured(escrowId, threshold, op, maxStaleness);
    }

    /// @inheritdoc IOracleConditionResolver
    function getLatestValue(uint256 escrowId) public view virtual returns (int256 value, uint256 timestamp) {
        ChainlinkStorage storage $ = _getChainlinkStorage();
        if (!$.configs[escrowId].configured) revert ConditionNotConfigured();

        AggregatorV3Interface aggregator = _getAggregator(escrowId);
        if (address(aggregator) == address(0)) revert InvalidAggregator();

        (, int256 answer,, uint256 updatedAt,) = aggregator.latestRoundData();

        if (answer <= 0 || updatedAt == 0) revert InvalidRoundData();

        return (answer, updatedAt);
    }

    /// @inheritdoc IOracleConditionResolver
    function isStale(uint256 escrowId) public view returns (bool) {
        ChainlinkStorage storage $ = _getChainlinkStorage();
        OracleConfig storage config = $.configs[escrowId];

        if (!config.configured) revert ConditionNotConfigured();

        (, uint256 timestamp) = getLatestValue(escrowId);
        return block.timestamp - timestamp > config.maxStaleness;
    }

    /// @inheritdoc IOracleConditionResolver
    function getThreshold(uint256 escrowId) external view returns (int256 threshold, ComparisonOp op) {
        ChainlinkStorage storage $ = _getChainlinkStorage();
        OracleConfig storage config = $.configs[escrowId];

        if (!config.configured) revert ConditionNotConfigured();

        return (config.threshold, config.op);
    }

    /// @inheritdoc IConditionResolver
    function isConditionMet(uint256 escrowId) external view virtual returns (bool) {
        ChainlinkStorage storage $ = _getChainlinkStorage();
        if (!$.configs[escrowId].configured) revert ConditionNotConfigured();

        if (isStale(escrowId)) {
            return false;
        }

        (int256 value,) = getLatestValue(escrowId);
        return _evaluateCondition(escrowId, value);
    }

    /// @notice Evaluate the condition using the latest oracle value.
    /// @dev Default implementation uses the configured threshold and comparison operator.
    ///      Override this for custom condition logic.
    /// @param escrowId The escrow identifier.
    /// @param value The latest oracle value.
    /// @return True if the condition is met.
    function _evaluateCondition(uint256 escrowId, int256 value) internal view virtual returns (bool) {
        ChainlinkStorage storage $ = _getChainlinkStorage();
        OracleConfig storage config = $.configs[escrowId];

        if (config.op == ComparisonOp.GreaterThan) return value > config.threshold;
        if (config.op == ComparisonOp.GreaterThanOrEqual) return value >= config.threshold;
        if (config.op == ComparisonOp.LessThan) return value < config.threshold;
        if (config.op == ComparisonOp.LessThanOrEqual) return value <= config.threshold;
        if (config.op == ComparisonOp.Equal) return value == config.threshold;
        if (config.op == ComparisonOp.NotEqual) return value != config.threshold;

        return false;
    }

    /// @notice Get the Chainlink aggregator for an escrow.
    /// @dev Concrete implementations must override this to provide the feed address.
    ///      This allows different escrows to use different feeds or the same feed.
    /// @param escrowId The escrow identifier.
    /// @return The Chainlink AggregatorV3Interface instance.
    function _getAggregator(uint256 escrowId) internal view virtual returns (AggregatorV3Interface);

    /// @inheritdoc ERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IConditionResolver).interfaceId
            || interfaceId == type(IOracleConditionResolver).interfaceId || super.supportsInterface(interfaceId);
    }
}
