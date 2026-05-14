// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ChainlinkConditionBase} from "./ChainlinkConditionBase.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @title ChainlinkPriceFeedResolver
/// @notice Concrete resolver using Chainlink Price Feeds for condition evaluation
/// @dev Allows escrows to be released based on price feed thresholds
///      Example: Release funds when ETH/USD > $2000
///
/// ## Usage Example
/// 1. Deploy this resolver
/// 2. Configure escrow with: abi.encode(feedAddress, threshold, op, maxStaleness)
///    - feedAddress: Chainlink price feed address (e.g., ETH/USD on Arbitrum Sepolia)
///    - threshold: Price threshold in feed decimals (e.g., 2000 * 10^8 for $2000)
///    - op: Comparison operator (0=GT, 1=GTE, 2=LT, 3=LTE, 4=EQ, 5=NEQ)
///    - maxStaleness: Maximum age of data in seconds (e.g., 3600 for 1 hour)
///
/// ## Chainlink Price Feed Addresses
/// Find feeds at: https://docs.chain.link/data-feeds/price-feeds/addresses
/// Arbitrum Sepolia Example:
/// - ETH/USD: 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165
/// - BTC/USD: 0x56a43EB56Da12C0dc1D972ACb089c06a5dEF8e69
contract ChainlinkPriceFeedResolver is ChainlinkConditionBase {
    /// @custom:storage-location erc7201:reineira.storage.ChainlinkPriceFeedResolver
    struct PriceFeedStorage {
        mapping(uint256 => address) feedAddresses;
    }

    // keccak256(abi.encode(uint256(keccak256("reineira.storage.ChainlinkPriceFeedResolver")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant PRICE_FEED_STORAGE_LOCATION =
        0x1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a00;

    event PriceFeedConfigured(uint256 indexed escrowId, address indexed feedAddress);

    error InvalidFeedAddress();

    function _getPriceFeedStorage() private pure returns (PriceFeedStorage storage $) {
        assembly {
            $.slot := PRICE_FEED_STORAGE_LOCATION
        }
    }

    /// @notice Configure the price feed condition for an escrow
    /// @dev Data format: abi.encode(address feedAddress, int256 threshold, uint8 op, uint256 maxStaleness)
    ///      feedAddress: Chainlink price feed contract address
    ///      threshold: Price threshold in feed decimals
    ///      op: Comparison operator (0-5)
    ///      maxStaleness: Maximum data age in seconds
    function onConditionSet(uint256 escrowId, bytes calldata data) external {
        (address feedAddress, int256 threshold, uint8 op, uint256 maxStaleness) =
            abi.decode(data, (address, int256, uint8, uint256));

        if (feedAddress == address(0)) revert InvalidFeedAddress();

        PriceFeedStorage storage $ = _getPriceFeedStorage();
        $.feedAddresses[escrowId] = feedAddress;

        bytes memory configData = abi.encode(threshold, op, maxStaleness);
        _configure(escrowId, configData);

        emit PriceFeedConfigured(escrowId, feedAddress);
    }

    /// @notice Get the price feed address for an escrow
    /// @param escrowId The escrow identifier
    /// @return The Chainlink price feed address
    function getFeedAddress(uint256 escrowId) external view returns (address) {
        PriceFeedStorage storage $ = _getPriceFeedStorage();
        return $.feedAddresses[escrowId];
    }

    /// @inheritdoc ChainlinkConditionBase
    function _getAggregator(uint256 escrowId) internal view override returns (AggregatorV3Interface) {
        PriceFeedStorage storage $ = _getPriceFeedStorage();
        return AggregatorV3Interface($.feedAddresses[escrowId]);
    }
}
