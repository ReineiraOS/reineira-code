// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ChainlinkPriceFeedResolver} from "../contracts/resolvers/ChainlinkPriceFeedResolver.sol";
import {IOracleConditionResolver} from "../contracts/interfaces/IOracleConditionResolver.sol";

/// @title Test DEPLOYED ChainlinkPriceFeedResolver on Arbitrum Sepolia
/// @notice Tests the REAL deployed contract, not a new deployment
/// @dev Run with: forge test --match-contract DeployedTest --fork-url $ARBITRUM_SEPOLIA_RPC_URL -vvv
contract ChainlinkPriceFeedResolverDeployedTest is Test {
    // REAL deployed contract address
    ChainlinkPriceFeedResolver public resolver = ChainlinkPriceFeedResolver(0x49DDce54E0dCe041fE2ab3590515b640289cE2de);

    // REAL Chainlink feeds on Arbitrum Sepolia
    address constant ETH_USD_FEED = 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165;
    address constant BTC_USD_FEED = 0x56a43EB56Da12C0dc1D972ACb089c06a5dEF8e69;
    address constant LINK_USD_FEED = 0x0FB99723Aee6f420beAD13e6bBB79b7E6F034298;

    function setUp() public {
        console.log("Testing DEPLOYED contract at:", address(resolver));
        console.log("Network: Arbitrum Sepolia");
    }

    /// @notice Test with REAL deployed contract and REAL ETH/USD feed
    function test_DeployedContract_ETHPrice() public {
        console.log("\n=== Testing DEPLOYED Contract - ETH/USD ===");

        uint256 escrowId = 999; // Use high ID to avoid conflicts

        // Configure: Release when ETH > $100
        int256 threshold = 100 * 10 ** 8;
        uint8 op = uint8(IOracleConditionResolver.ComparisonOp.GreaterThan);
        uint256 maxStaleness = 86400; // 24 hours

        bytes memory data = abi.encode(ETH_USD_FEED, threshold, op, maxStaleness);

        // This will actually call the deployed contract
        vm.prank(address(this));
        resolver.onConditionSet(escrowId, data);

        // Get REAL price from deployed contract
        (int256 price, uint256 timestamp) = resolver.getLatestValue(escrowId);

        console.log("ETH/USD Price from DEPLOYED contract:", uint256(price) / 10 ** 8);
        console.log("Last Updated:", timestamp);
        console.log("Contract Address:", address(resolver));

        // Verify it works
        bool isMet = resolver.isConditionMet(escrowId);
        console.log("Condition Met (ETH > $100):", isMet);

        assertTrue(isMet, "ETH should be > $100");
        assertTrue(price > threshold, "Price should exceed threshold");
    }

    /// @notice Test BTC price with deployed contract
    function test_DeployedContract_BTCPrice() public {
        console.log("\n=== Testing DEPLOYED Contract - BTC/USD ===");

        uint256 escrowId = 1000;

        int256 threshold = 1000 * 10 ** 8;
        uint8 op = uint8(IOracleConditionResolver.ComparisonOp.GreaterThan);
        uint256 maxStaleness = 86400;

        bytes memory data = abi.encode(BTC_USD_FEED, threshold, op, maxStaleness);
        resolver.onConditionSet(escrowId, data);

        (int256 price,) = resolver.getLatestValue(escrowId);
        console.log("BTC/USD Price from DEPLOYED contract:", uint256(price) / 10 ** 8);

        bool isMet = resolver.isConditionMet(escrowId);
        assertTrue(isMet, "BTC should be > $1000");
    }

    /// @notice Verify deployed contract address matches
    function test_DeployedContract_Address() public view {
        console.log("\n=== Verifying Deployment ===");
        console.log("Expected Address: 0x49DDce54E0dCe041fE2ab3590515b640289cE2de");
        console.log("Actual Address:", address(resolver));

        assertEq(address(resolver), 0x49DDce54E0dCe041fE2ab3590515b640289cE2de, "Contract address mismatch");
    }

    /// @notice Test that deployed contract can read feed address
    function test_DeployedContract_GetFeedAddress() public {
        console.log("\n=== Testing Feed Address Storage ===");

        uint256 escrowId = 1001;
        bytes memory data = abi.encode(ETH_USD_FEED, int256(100 * 10 ** 8), uint8(0), uint256(86400));
        resolver.onConditionSet(escrowId, data);

        address storedFeed = resolver.getFeedAddress(escrowId);
        console.log("Stored Feed Address:", storedFeed);
        console.log("Expected Feed Address:", ETH_USD_FEED);

        assertEq(storedFeed, ETH_USD_FEED, "Feed address should match");
    }

    /// @notice Test staleness detection with deployed contract
    function test_DeployedContract_Staleness() public {
        console.log("\n=== Testing Staleness Detection ===");

        uint256 escrowId = 1002;

        // Very short staleness window
        bytes memory data = abi.encode(ETH_USD_FEED, int256(100 * 10 ** 8), uint8(0), uint256(1));
        resolver.onConditionSet(escrowId, data);

        bool isStale = resolver.isStale(escrowId);
        console.log("Is Stale (1 second threshold):", isStale);

        // Should be stale since Chainlink doesn't update every second
        assertTrue(isStale, "Should be stale with 1 second threshold");
    }
}
