// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {SimpleEscrow} from "../contracts/test/SimpleEscrow.sol";
import {ChainlinkPriceFeedResolver} from "../contracts/resolvers/ChainlinkPriceFeedResolver.sol";
import {IOracleConditionResolver} from "../contracts/interfaces/IOracleConditionResolver.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @title Comprehensive Chainlink Condition Test Suite
/// @notice Tests ALL possible condition outcomes and edge cases
/// @dev Run with: forge test --match-contract ChainlinkConditions --fork-url $ARBITRUM_SEPOLIA_RPC_URL -vv
contract ChainlinkConditionsTest is Test {
    SimpleEscrow public escrow;
    ChainlinkPriceFeedResolver public resolver;

    address constant ETH_USD_FEED = 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165;
    address constant BTC_USD_FEED = 0x56a43EB56Da12C0dc1D972ACb089c06a5dEF8e69;
    address constant LINK_USD_FEED = 0x0FB99723Aee6f420beAD13e6bBB79b7E6F034298;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");

    int256 currentETHPrice;
    int256 currentBTCPrice;
    int256 currentLINKPrice;

    function setUp() public {
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(charlie, 100 ether);

        resolver = new ChainlinkPriceFeedResolver();
        escrow = new SimpleEscrow();

        // Get current prices
        AggregatorV3Interface ethFeed = AggregatorV3Interface(ETH_USD_FEED);
        AggregatorV3Interface btcFeed = AggregatorV3Interface(BTC_USD_FEED);
        AggregatorV3Interface linkFeed = AggregatorV3Interface(LINK_USD_FEED);

        (, currentETHPrice,,,) = ethFeed.latestRoundData();
        (, currentBTCPrice,,,) = btcFeed.latestRoundData();
        (, currentLINKPrice,,,) = linkFeed.latestRoundData();

        console.log("=== Current Prices ===");
        console.log("ETH/USD:", uint256(currentETHPrice) / 10 ** 8);
        console.log("BTC/USD:", uint256(currentBTCPrice) / 10 ** 8);
        console.log("LINK/USD:", uint256(currentLINKPrice) / 10 ** 8);
    }

    // ============================================
    // GREATER THAN Tests
    // ============================================

    function test_GreaterThan_ConditionMet() public {
        console.log("\n=== GT: Condition MET ===");
        
        int256 threshold = currentETHPrice - (100 * 10 ** 8); // Below current
        bytes memory data = abi.encode(ETH_USD_FEED, threshold, uint8(0), 3600);
        
        vm.prank(alice);
        uint256 id = escrow.createEscrow{value: 1 ether}(bob, address(resolver), data);
        
        assertTrue(escrow.isConditionMet(id), "Should be met");
        console.log("Result: TRUE");
    }

    function test_GreaterThan_ConditionNotMet() public {
        console.log("\n=== GT: Condition NOT MET ===");
        
        int256 threshold = currentETHPrice + (100 * 10 ** 8); // Above current
        bytes memory data = abi.encode(ETH_USD_FEED, threshold, uint8(0), 3600);
        
        vm.prank(alice);
        uint256 id = escrow.createEscrow{value: 1 ether}(bob, address(resolver), data);
        
        assertFalse(escrow.isConditionMet(id), "Should NOT be met");
        console.log("Result: FALSE");
    }

    function test_GreaterThan_ExactlyEqual() public {
        console.log("\n=== GT: Exactly Equal ===");
        
        bytes memory data = abi.encode(ETH_USD_FEED, currentETHPrice, uint8(0), 3600);
        
        vm.prank(alice);
        uint256 id = escrow.createEscrow{value: 1 ether}(bob, address(resolver), data);
        
        assertFalse(escrow.isConditionMet(id), "Should NOT be met (not strictly greater)");
        console.log("Result: FALSE");
    }

    // ============================================
    // GREATER THAN OR EQUAL Tests
    // ============================================

    function test_GreaterThanOrEqual_ConditionMet() public {
        console.log("\n=== GTE: Condition MET ===");
        
        int256 threshold = currentETHPrice - (100 * 10 ** 8);
        bytes memory data = abi.encode(ETH_USD_FEED, threshold, uint8(1), 3600);
        
        vm.prank(alice);
        uint256 id = escrow.createEscrow{value: 1 ether}(bob, address(resolver), data);
        
        assertTrue(escrow.isConditionMet(id), "Should be met");
        console.log("Result: TRUE");
    }

    function test_GreaterThanOrEqual_ExactlyEqual() public {
        console.log("\n=== GTE: Exactly Equal ===");
        
        bytes memory data = abi.encode(ETH_USD_FEED, currentETHPrice, uint8(1), 3600);
        
        vm.prank(alice);
        uint256 id = escrow.createEscrow{value: 1 ether}(bob, address(resolver), data);
        
        assertTrue(escrow.isConditionMet(id), "Should be met (equal counts)");
        console.log("Result: TRUE");
    }

    function test_GreaterThanOrEqual_ConditionNotMet() public {
        console.log("\n=== GTE: Condition NOT MET ===");
        
        int256 threshold = currentETHPrice + (100 * 10 ** 8);
        bytes memory data = abi.encode(ETH_USD_FEED, threshold, uint8(1), 3600);
        
        vm.prank(alice);
        uint256 id = escrow.createEscrow{value: 1 ether}(bob, address(resolver), data);
        
        assertFalse(escrow.isConditionMet(id), "Should NOT be met");
        console.log("Result: FALSE");
    }

    // ============================================
    // LESS THAN Tests
    // ============================================

    function test_LessThan_ConditionMet() public {
        console.log("\n=== LT: Condition MET ===");
        
        int256 threshold = currentETHPrice + (100 * 10 ** 8); // Above current
        bytes memory data = abi.encode(ETH_USD_FEED, threshold, uint8(2), 3600);
        
        vm.prank(alice);
        uint256 id = escrow.createEscrow{value: 1 ether}(bob, address(resolver), data);
        
        assertTrue(escrow.isConditionMet(id), "Should be met");
        console.log("Result: TRUE");
    }

    function test_LessThan_ConditionNotMet() public {
        console.log("\n=== LT: Condition NOT MET ===");
        
        int256 threshold = currentETHPrice - (100 * 10 ** 8); // Below current
        bytes memory data = abi.encode(ETH_USD_FEED, threshold, uint8(2), 3600);
        
        vm.prank(alice);
        uint256 id = escrow.createEscrow{value: 1 ether}(bob, address(resolver), data);
        
        assertFalse(escrow.isConditionMet(id), "Should NOT be met");
        console.log("Result: FALSE");
    }

    function test_LessThan_ExactlyEqual() public {
        console.log("\n=== LT: Exactly Equal ===");
        
        bytes memory data = abi.encode(ETH_USD_FEED, currentETHPrice, uint8(2), 3600);
        
        vm.prank(alice);
        uint256 id = escrow.createEscrow{value: 1 ether}(bob, address(resolver), data);
        
        assertFalse(escrow.isConditionMet(id), "Should NOT be met (not strictly less)");
        console.log("Result: FALSE");
    }

    // ============================================
    // LESS THAN OR EQUAL Tests
    // ============================================

    function test_LessThanOrEqual_ConditionMet() public {
        console.log("\n=== LTE: Condition MET ===");
        
        int256 threshold = currentETHPrice + (100 * 10 ** 8);
        bytes memory data = abi.encode(ETH_USD_FEED, threshold, uint8(3), 3600);
        
        vm.prank(alice);
        uint256 id = escrow.createEscrow{value: 1 ether}(bob, address(resolver), data);
        
        assertTrue(escrow.isConditionMet(id), "Should be met");
        console.log("Result: TRUE");
    }

    function test_LessThanOrEqual_ExactlyEqual() public {
        console.log("\n=== LTE: Exactly Equal ===");
        
        bytes memory data = abi.encode(ETH_USD_FEED, currentETHPrice, uint8(3), 3600);
        
        vm.prank(alice);
        uint256 id = escrow.createEscrow{value: 1 ether}(bob, address(resolver), data);
        
        assertTrue(escrow.isConditionMet(id), "Should be met (equal counts)");
        console.log("Result: TRUE");
    }

    function test_LessThanOrEqual_ConditionNotMet() public {
        console.log("\n=== LTE: Condition NOT MET ===");
        
        int256 threshold = currentETHPrice - (100 * 10 ** 8);
        bytes memory data = abi.encode(ETH_USD_FEED, threshold, uint8(3), 3600);
        
        vm.prank(alice);
        uint256 id = escrow.createEscrow{value: 1 ether}(bob, address(resolver), data);
        
        assertFalse(escrow.isConditionMet(id), "Should NOT be met");
        console.log("Result: FALSE");
    }

    // ============================================
    // EQUAL Tests
    // ============================================

    function test_Equal_ConditionMet() public {
        console.log("\n=== EQ: Condition MET ===");
        
        bytes memory data = abi.encode(ETH_USD_FEED, currentETHPrice, uint8(4), 3600);
        
        vm.prank(alice);
        uint256 id = escrow.createEscrow{value: 1 ether}(bob, address(resolver), data);
        
        assertTrue(escrow.isConditionMet(id), "Should be met");
        console.log("Result: TRUE");
    }

    function test_Equal_ConditionNotMet_Higher() public {
        console.log("\n=== EQ: Condition NOT MET (Higher) ===");
        
        int256 threshold = currentETHPrice + 1;
        bytes memory data = abi.encode(ETH_USD_FEED, threshold, uint8(4), 3600);
        
        vm.prank(alice);
        uint256 id = escrow.createEscrow{value: 1 ether}(bob, address(resolver), data);
        
        assertFalse(escrow.isConditionMet(id), "Should NOT be met");
        console.log("Result: FALSE");
    }

    function test_Equal_ConditionNotMet_Lower() public {
        console.log("\n=== EQ: Condition NOT MET (Lower) ===");
        
        int256 threshold = currentETHPrice - 1;
        bytes memory data = abi.encode(ETH_USD_FEED, threshold, uint8(4), 3600);
        
        vm.prank(alice);
        uint256 id = escrow.createEscrow{value: 1 ether}(bob, address(resolver), data);
        
        assertFalse(escrow.isConditionMet(id), "Should NOT be met");
        console.log("Result: FALSE");
    }

    // ============================================
    // NOT EQUAL Tests
    // ============================================

    function test_NotEqual_ConditionMet_Higher() public {
        console.log("\n=== NEQ: Condition MET (Higher) ===");
        
        int256 threshold = currentETHPrice + 1;
        bytes memory data = abi.encode(ETH_USD_FEED, threshold, uint8(5), 3600);
        
        vm.prank(alice);
        uint256 id = escrow.createEscrow{value: 1 ether}(bob, address(resolver), data);
        
        assertTrue(escrow.isConditionMet(id), "Should be met");
        console.log("Result: TRUE");
    }

    function test_NotEqual_ConditionMet_Lower() public {
        console.log("\n=== NEQ: Condition MET (Lower) ===");
        
        int256 threshold = currentETHPrice - 1;
        bytes memory data = abi.encode(ETH_USD_FEED, threshold, uint8(5), 3600);
        
        vm.prank(alice);
        uint256 id = escrow.createEscrow{value: 1 ether}(bob, address(resolver), data);
        
        assertTrue(escrow.isConditionMet(id), "Should be met");
        console.log("Result: TRUE");
    }

    function test_NotEqual_ConditionNotMet() public {
        console.log("\n=== NEQ: Condition NOT MET ===");
        
        bytes memory data = abi.encode(ETH_USD_FEED, currentETHPrice, uint8(5), 3600);
        
        vm.prank(alice);
        uint256 id = escrow.createEscrow{value: 1 ether}(bob, address(resolver), data);
        
        assertFalse(escrow.isConditionMet(id), "Should NOT be met (values are equal)");
        console.log("Result: FALSE");
    }

    // ============================================
    // STALENESS Tests
    // ============================================

    function test_Staleness_Fresh() public {
        console.log("\n=== STALENESS: Fresh Data ===");
        
        bytes memory data = abi.encode(ETH_USD_FEED, currentETHPrice - (100 * 10 ** 8), uint8(0), 86400); // 24 hours
        
        vm.prank(alice);
        uint256 id = escrow.createEscrow{value: 1 ether}(bob, address(resolver), data);
        
        assertFalse(resolver.isStale(id), "Should NOT be stale");
        assertTrue(escrow.isConditionMet(id), "Condition should be met");
        console.log("Data is fresh (< 24 hours old)");
    }

    function test_Staleness_Stale() public {
        console.log("\n=== STALENESS: Stale Data ===");
        
        bytes memory data = abi.encode(ETH_USD_FEED, currentETHPrice - (100 * 10 ** 8), uint8(0), 1); // 1 second
        
        vm.prank(alice);
        uint256 id = escrow.createEscrow{value: 1 ether}(bob, address(resolver), data);
        
        assertTrue(resolver.isStale(id), "Should be stale");
        assertFalse(escrow.isConditionMet(id), "Condition should be FALSE when stale");
        console.log("Data is stale (> 1 second old)");
    }

    // ============================================
    // MULTIPLE FEEDS Tests
    // ============================================

    function test_MultipleFeedsETHAndBTC() public {
        console.log("\n=== MULTIPLE FEEDS: ETH and BTC ===");
        
        // ETH escrow
        bytes memory ethData = abi.encode(ETH_USD_FEED, currentETHPrice - (100 * 10 ** 8), uint8(0), 3600);
        vm.prank(alice);
        uint256 ethId = escrow.createEscrow{value: 1 ether}(bob, address(resolver), ethData);
        
        // BTC escrow
        bytes memory btcData = abi.encode(BTC_USD_FEED, currentBTCPrice - (1000 * 10 ** 8), uint8(0), 3600);
        vm.prank(alice);
        uint256 btcId = escrow.createEscrow{value: 1 ether}(bob, address(resolver), btcData);
        
        assertTrue(escrow.isConditionMet(ethId), "ETH condition should be met");
        assertTrue(escrow.isConditionMet(btcId), "BTC condition should be met");
        
        console.log("ETH escrow:", ethId, "- Met");
        console.log("BTC escrow:", btcId, "- Met");
    }

    function test_MultipleFeedsAllThree() public {
        console.log("\n=== MULTIPLE FEEDS: ETH, BTC, LINK ===");
        
        bytes memory ethData = abi.encode(ETH_USD_FEED, currentETHPrice + (100 * 10 ** 8), uint8(2), 3600); // LT
        bytes memory btcData = abi.encode(BTC_USD_FEED, currentBTCPrice - (1000 * 10 ** 8), uint8(0), 3600); // GT
        bytes memory linkData = abi.encode(LINK_USD_FEED, currentLINKPrice, uint8(5), 3600); // NEQ (will be false)
        
        vm.startPrank(alice);
        uint256 ethId = escrow.createEscrow{value: 1 ether}(bob, address(resolver), ethData);
        uint256 btcId = escrow.createEscrow{value: 1 ether}(bob, address(resolver), btcData);
        uint256 linkId = escrow.createEscrow{value: 1 ether}(bob, address(resolver), linkData);
        vm.stopPrank();
        
        assertTrue(escrow.isConditionMet(ethId), "ETH < threshold");
        assertTrue(escrow.isConditionMet(btcId), "BTC > threshold");
        assertFalse(escrow.isConditionMet(linkId), "LINK == threshold (NEQ fails)");
        
        console.log("ETH (LT):", ethId, "- Met");
        console.log("BTC (GT):", btcId, "- Met");
        console.log("LINK (NEQ):", linkId, "- NOT Met");
    }

    // ============================================
    // EDGE CASES
    // ============================================

    function test_EdgeCase_ZeroThreshold() public {
        console.log("\n=== EDGE CASE: Zero Threshold ===");
        
        bytes memory data = abi.encode(ETH_USD_FEED, int256(0), uint8(0), 3600); // GT 0
        
        vm.prank(alice);
        uint256 id = escrow.createEscrow{value: 1 ether}(bob, address(resolver), data);
        
        assertTrue(escrow.isConditionMet(id), "Price should be > 0");
        console.log("ETH > 0 = TRUE");
    }

    function test_EdgeCase_NegativeThreshold() public {
        console.log("\n=== EDGE CASE: Negative Threshold ===");
        
        bytes memory data = abi.encode(ETH_USD_FEED, int256(-1000), uint8(0), 3600); // GT -1000
        
        vm.prank(alice);
        uint256 id = escrow.createEscrow{value: 1 ether}(bob, address(resolver), data);
        
        assertTrue(escrow.isConditionMet(id), "Price should be > -1000");
        console.log("ETH > -1000 = TRUE");
    }

    function test_EdgeCase_VeryLargeThreshold() public {
        console.log("\n=== EDGE CASE: Very Large Threshold ===");
        
        bytes memory data = abi.encode(ETH_USD_FEED, type(int256).max, uint8(2), 3600); // LT max
        
        vm.prank(alice);
        uint256 id = escrow.createEscrow{value: 1 ether}(bob, address(resolver), data);
        
        assertTrue(escrow.isConditionMet(id), "Price should be < max int256");
        console.log("ETH < max int256 = TRUE");
    }

    // ============================================
    // RELEASE FLOW Tests
    // ============================================

    function test_ReleaseFlow_ConditionMet() public {
        console.log("\n=== RELEASE FLOW: Condition Met ===");
        
        bytes memory data = abi.encode(ETH_USD_FEED, currentETHPrice - (100 * 10 ** 8), uint8(0), 3600);
        
        vm.prank(alice);
        uint256 id = escrow.createEscrow{value: 1 ether}(bob, address(resolver), data);
        
        uint256 bobBefore = bob.balance;
        escrow.release(id);
        uint256 bobAfter = bob.balance;
        
        assertEq(bobAfter - bobBefore, 1 ether, "Bob should receive 1 ETH");
        console.log("Funds released to beneficiary");
    }

    function test_ReleaseFlow_ConditionNotMet_Reverts() public {
        console.log("\n=== RELEASE FLOW: Condition Not Met (Reverts) ===");
        
        bytes memory data = abi.encode(ETH_USD_FEED, currentETHPrice + (1000 * 10 ** 8), uint8(0), 3600);
        
        vm.prank(alice);
        uint256 id = escrow.createEscrow{value: 1 ether}(bob, address(resolver), data);
        
        vm.expectRevert(SimpleEscrow.ConditionNotMet.selector);
        escrow.release(id);
        
        console.log("Release correctly reverted");
    }

    function test_ReleaseFlow_MultipleUsers() public {
        console.log("\n=== RELEASE FLOW: Multiple Users ===");
        
        bytes memory data = abi.encode(ETH_USD_FEED, currentETHPrice - (100 * 10 ** 8), uint8(0), 3600);
        
        // Alice -> Bob
        vm.prank(alice);
        uint256 id1 = escrow.createEscrow{value: 1 ether}(bob, address(resolver), data);
        
        // Bob -> Charlie
        vm.prank(bob);
        uint256 id2 = escrow.createEscrow{value: 2 ether}(charlie, address(resolver), data);
        
        // Charlie -> Alice
        vm.prank(charlie);
        uint256 id3 = escrow.createEscrow{value: 0.5 ether}(alice, address(resolver), data);
        
        uint256 bobBefore = bob.balance;
        uint256 charlieBefore = charlie.balance;
        uint256 aliceBefore = alice.balance;
        
        escrow.release(id1);
        escrow.release(id2);
        escrow.release(id3);
        
        assertEq(bob.balance - bobBefore, 1 ether, "Bob gets 1 ETH");
        assertEq(charlie.balance - charlieBefore, 2 ether, "Charlie gets 2 ETH");
        assertEq(alice.balance - aliceBefore, 0.5 ether, "Alice gets 0.5 ETH");
        
        console.log("All escrows released correctly");
    }
}
