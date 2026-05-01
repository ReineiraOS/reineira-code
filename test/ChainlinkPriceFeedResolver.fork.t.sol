// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ChainlinkPriceFeedResolver} from "../contracts/resolvers/ChainlinkPriceFeedResolver.sol";
import {IOracleConditionResolver} from "../contracts/interfaces/IOracleConditionResolver.sol";

/// @title ChainlinkPriceFeedResolver Fork Test
/// @notice REAL integration test using LIVE Chainlink feeds on Arbitrum Sepolia
/// @dev Run with: forge test --match-contract ChainlinkPriceFeedResolverForkTest --fork-url $ARBITRUM_SEPOLIA_RPC_URL -vvv
contract ChainlinkPriceFeedResolverForkTest is Test {
    ChainlinkPriceFeedResolver public resolver;

    // REAL Chainlink feeds on Arbitrum Sepolia
    address constant ETH_USD_FEED = 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165;
    address constant BTC_USD_FEED = 0x56a43EB56Da12C0dc1D972ACb089c06a5dEF8e69;
    address constant LINK_USD_FEED = 0x0FB99723Aee6f420beAD13e6bBB79b7E6F034298;

    uint256 constant ESCROW_ID = 1;

    function setUp() public {
        // Deploy resolver
        resolver = new ChainlinkPriceFeedResolver();
        console.log("Resolver deployed at:", address(resolver));
    }

    /// @notice Test with REAL ETH/USD price feed
    function test_RealETHUSDFeed() public {
        console.log("\n=== REAL ETH/USD Price Feed Test ===");

        // Configure: Release when ETH > $100 (should always be true)
        int256 threshold = 100 * 10 ** 8; // $100 with 8 decimals
        uint8 op = uint8(IOracleConditionResolver.ComparisonOp.GreaterThan);
        uint256 maxStaleness = 86400; // 24 hours

        bytes memory data = abi.encode(ETH_USD_FEED, threshold, op, maxStaleness);
        resolver.onConditionSet(ESCROW_ID, data);

        // Get REAL price from Chainlink
        (int256 price, uint256 timestamp) = resolver.getLatestValue(ESCROW_ID);

        console.log("ETH/USD Price:", uint256(price) / 10 ** 8);
        console.log("Last Updated:", timestamp);
        console.log("Time Since Update:", block.timestamp - timestamp, "seconds");

        // Check staleness
        bool isStale = resolver.isStale(ESCROW_ID);
        console.log("Is Stale:", isStale);

        // Check condition
        bool isMet = resolver.isConditionMet(ESCROW_ID);
        console.log("Condition Met (ETH > $100):", isMet);

        // ETH should always be > $100
        assertTrue(isMet, "ETH price should be > $100");
        assertFalse(isStale, "Data should not be stale");
        assertTrue(price > threshold, "Price should exceed threshold");
    }

    /// @notice Test with REAL BTC/USD price feed
    function test_RealBTCUSDFeed() public {
        console.log("\n=== REAL BTC/USD Price Feed Test ===");

        uint256 escrowId = 2;

        // Configure: Release when BTC > $1000 (should always be true)
        int256 threshold = 1000 * 10 ** 8;
        uint8 op = uint8(IOracleConditionResolver.ComparisonOp.GreaterThan);
        uint256 maxStaleness = 86400;

        bytes memory data = abi.encode(BTC_USD_FEED, threshold, op, maxStaleness);
        resolver.onConditionSet(escrowId, data);

        (int256 price, uint256 timestamp) = resolver.getLatestValue(escrowId);

        console.log("BTC/USD Price:", uint256(price) / 10 ** 8);
        console.log("Last Updated:", timestamp);

        bool isMet = resolver.isConditionMet(escrowId);
        console.log("Condition Met (BTC > $1000):", isMet);

        assertTrue(isMet, "BTC price should be > $1000");
    }

    /// @notice Test with REAL LINK/USD price feed
    function test_RealLINKUSDFeed() public {
        console.log("\n=== REAL LINK/USD Price Feed Test ===");

        uint256 escrowId = 3;

        // Configure: Release when LINK > $1 (should be true)
        int256 threshold = 1 * 10 ** 8;
        uint8 op = uint8(IOracleConditionResolver.ComparisonOp.GreaterThan);
        uint256 maxStaleness = 86400;

        bytes memory data = abi.encode(LINK_USD_FEED, threshold, op, maxStaleness);
        resolver.onConditionSet(escrowId, data);

        (int256 price, uint256 timestamp) = resolver.getLatestValue(escrowId);

        console.log("LINK/USD Price:", uint256(price) / 10 ** 8);
        console.log("Last Updated:", timestamp);

        bool isMet = resolver.isConditionMet(escrowId);
        console.log("Condition Met (LINK > $1):", isMet);

        assertTrue(price > 0, "LINK price should be positive");
    }

    /// @notice Test LessThan operator with real data
    function test_LessThanOperator() public {
        console.log("\n=== LessThan Operator Test ===");

        uint256 escrowId = 4;

        // Configure: Release when ETH < $1,000,000 (should always be true)
        int256 threshold = 1000000 * 10 ** 8;
        uint8 op = uint8(IOracleConditionResolver.ComparisonOp.LessThan);
        uint256 maxStaleness = 86400;

        bytes memory data = abi.encode(ETH_USD_FEED, threshold, op, maxStaleness);
        resolver.onConditionSet(escrowId, data);

        (int256 price,) = resolver.getLatestValue(escrowId);
        bool isMet = resolver.isConditionMet(escrowId);

        console.log("ETH Price:", uint256(price) / 10 ** 8);
        console.log("Threshold: $1,000,000");
        console.log("Condition Met (ETH < $1M):", isMet);

        assertTrue(isMet, "ETH should be < $1M");
    }

    /// @notice Test staleness detection with very short timeout
    function test_StalenessDetection() public {
        console.log("\n=== Staleness Detection Test ===");

        uint256 escrowId = 5;

        // Configure with 1 second staleness (will definitely be stale)
        int256 threshold = 100 * 10 ** 8;
        uint8 op = uint8(IOracleConditionResolver.ComparisonOp.GreaterThan);
        uint256 maxStaleness = 1; // 1 second

        bytes memory data = abi.encode(ETH_USD_FEED, threshold, op, maxStaleness);
        resolver.onConditionSet(escrowId, data);

        (, uint256 timestamp) = resolver.getLatestValue(escrowId);
        uint256 age = block.timestamp - timestamp;

        console.log("Data Age:", age, "seconds");
        console.log("Max Staleness: 1 second");

        bool isStale = resolver.isStale(escrowId);
        console.log("Is Stale:", isStale);

        // Should be stale since update is older than 1 second
        assertTrue(isStale, "Data should be stale with 1 second timeout");

        // Condition should return false when stale
        bool isMet = resolver.isConditionMet(escrowId);
        console.log("Condition Met (when stale):", isMet);
        assertFalse(isMet, "Condition should be false when data is stale");
    }

    /// @notice Compare multiple feeds
    function test_CompareMultipleFeeds() public {
        console.log("\n=== Compare Multiple Feeds ===");

        // Get all three prices
        uint256 ethEscrow = 10;
        uint256 btcEscrow = 11;
        uint256 linkEscrow = 12;

        bytes memory ethData = abi.encode(ETH_USD_FEED, int256(0), uint8(0), uint256(86400));
        bytes memory btcData = abi.encode(BTC_USD_FEED, int256(0), uint8(0), uint256(86400));
        bytes memory linkData = abi.encode(LINK_USD_FEED, int256(0), uint8(0), uint256(86400));

        resolver.onConditionSet(ethEscrow, ethData);
        resolver.onConditionSet(btcEscrow, btcData);
        resolver.onConditionSet(linkEscrow, linkData);

        (int256 ethPrice,) = resolver.getLatestValue(ethEscrow);
        (int256 btcPrice,) = resolver.getLatestValue(btcEscrow);
        (int256 linkPrice,) = resolver.getLatestValue(linkEscrow);

        console.log("\nCurrent Prices:");
        console.log("ETH/USD:  $", uint256(ethPrice) / 10 ** 8);
        console.log("BTC/USD:  $", uint256(btcPrice) / 10 ** 8);
        console.log("LINK/USD: $", uint256(linkPrice) / 10 ** 8);

        // BTC should be more expensive than ETH
        assertTrue(btcPrice > ethPrice, "BTC should be more expensive than ETH");
    }

    /// @notice Test all comparison operators
    function test_AllOperators() public {
        console.log("\n=== All Comparison Operators ===");

        // First configure ESCROW_ID to get current price
        bytes memory setupData = abi.encode(ETH_USD_FEED, int256(0), uint8(0), uint256(86400));
        resolver.onConditionSet(ESCROW_ID, setupData);

        (int256 currentPrice,) = resolver.getLatestValue(ESCROW_ID);
        console.log("Current ETH Price:", uint256(currentPrice) / 10 ** 8);

        // Test each operator
        uint256 escrowBase = 100;

        // GreaterThan: price > (current - 100)
        {
            uint256 eid = escrowBase + 1;
            int256 threshold = currentPrice - (100 * 10 ** 8);
            bytes memory data = abi.encode(ETH_USD_FEED, threshold, uint8(0), uint256(86400));
            resolver.onConditionSet(eid, data);
            assertTrue(resolver.isConditionMet(eid), "GreaterThan should work");
            console.log("GreaterThan: PASS");
        }

        // LessThan: price < (current + 100)
        {
            uint256 eid = escrowBase + 2;
            int256 threshold = currentPrice + (100 * 10 ** 8);
            bytes memory data = abi.encode(ETH_USD_FEED, threshold, uint8(2), uint256(86400));
            resolver.onConditionSet(eid, data);
            assertTrue(resolver.isConditionMet(eid), "LessThan should work");
            console.log("LessThan: PASS");
        }

        // NotEqual: price != (current + 1)
        {
            uint256 eid = escrowBase + 3;
            int256 threshold = currentPrice + 1;
            bytes memory data = abi.encode(ETH_USD_FEED, threshold, uint8(5), uint256(86400));
            resolver.onConditionSet(eid, data);
            assertTrue(resolver.isConditionMet(eid), "NotEqual should work");
            console.log("NotEqual: PASS");
        }
    }
}
