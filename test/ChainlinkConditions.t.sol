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

        resolver = new ChainlinkPriceFeedResolver(address(this));
        escrow = new SimpleEscrow();

        // Grant PROTOCOL_ROLE to SimpleEscrow so it can call onConditionSet
        resolver.grantProtocolRole(address(escrow));

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

    // ============================================
    // LESS THAN Tests
    // ============================================

    function test_LessThan_ConditionMet() public {
        console.log("\n=== LT: Condition MET ===");

        int256 threshold = currentBTCPrice + (1000 * 10 ** 8); // Above current
        bytes memory data = abi.encode(BTC_USD_FEED, threshold, uint8(2), 3600);

        vm.prank(alice);
        uint256 id = escrow.createEscrow{value: 1 ether}(bob, address(resolver), data);

        assertTrue(escrow.isConditionMet(id), "Should be met");
        console.log("Result: TRUE");
    }

    function test_LessThan_ConditionNotMet() public {
        console.log("\n=== LT: Condition NOT MET ===");

        int256 threshold = currentBTCPrice - (1000 * 10 ** 8); // Below current
        bytes memory data = abi.encode(BTC_USD_FEED, threshold, uint8(2), 3600);

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

        bytes memory data = abi.encode(LINK_USD_FEED, currentLINKPrice, uint8(4), 3600);

        vm.prank(alice);
        uint256 id = escrow.createEscrow{value: 1 ether}(bob, address(resolver), data);

        assertTrue(escrow.isConditionMet(id), "Should be met");
        console.log("Result: TRUE");
    }

    function test_Equal_ConditionNotMet() public {
        console.log("\n=== EQ: Condition NOT MET ===");

        int256 threshold = currentLINKPrice + (1 * 10 ** 8);
        bytes memory data = abi.encode(LINK_USD_FEED, threshold, uint8(4), 3600);

        vm.prank(alice);
        uint256 id = escrow.createEscrow{value: 1 ether}(bob, address(resolver), data);

        assertFalse(escrow.isConditionMet(id), "Should NOT be met");
        console.log("Result: FALSE");
    }

    // ============================================
    // GTE / LTE Tests
    // ============================================

    function test_GreaterThanOrEqual_ConditionMet() public {
        console.log("\n=== GTE: Condition MET ===");

        bytes memory data = abi.encode(ETH_USD_FEED, currentETHPrice, uint8(1), 3600);

        vm.prank(alice);
        uint256 id = escrow.createEscrow{value: 1 ether}(bob, address(resolver), data);

        assertTrue(escrow.isConditionMet(id), "Should be met");
        console.log("Result: TRUE");
    }

    function test_LessThanOrEqual_ConditionMet() public {
        console.log("\n=== LTE: Condition MET ===");

        bytes memory data = abi.encode(BTC_USD_FEED, currentBTCPrice, uint8(3), 3600);

        vm.prank(alice);
        uint256 id = escrow.createEscrow{value: 1 ether}(bob, address(resolver), data);

        assertTrue(escrow.isConditionMet(id), "Should be met");
        console.log("Result: TRUE");
    }

    // ============================================
    // NOT EQUAL Tests
    // ============================================

    function test_NotEqual_ConditionMet() public {
        console.log("\n=== NEQ: Condition MET ===");

        int256 threshold = currentETHPrice + (100 * 10 ** 8);
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

        assertFalse(escrow.isConditionMet(id), "Should NOT be met");
        console.log("Result: FALSE");
    }

    // ============================================
    // STALENESS Tests
    // ============================================

    function test_StaleData_ReturnsFalse() public {
        console.log("\n=== STALE: Returns FALSE ===");

        bytes memory data = abi.encode(ETH_USD_FEED, currentETHPrice - (100 * 10 ** 8), uint8(0), 1);

        vm.prank(alice);
        uint256 id = escrow.createEscrow{value: 1 ether}(bob, address(resolver), data);

        // Warp forward past maxStaleness
        vm.warp(block.timestamp + 2);

        assertFalse(escrow.isConditionMet(id), "Should be false due to stale data");
        console.log("Result: FALSE (stale)");
    }

    // ============================================
    // ESCROW INTEGRATION Tests
    // ============================================

    function test_EscrowRelease_WhenConditionMet() public {
        console.log("\n=== Escrow Release: Condition MET ===");

        int256 threshold = currentETHPrice - (100 * 10 ** 8);
        bytes memory data = abi.encode(ETH_USD_FEED, threshold, uint8(0), 3600);

        vm.prank(alice);
        uint256 id = escrow.createEscrow{value: 1 ether}(bob, address(resolver), data);

        uint256 bobBalanceBefore = bob.balance;

        vm.prank(bob);
        escrow.release(id);

        assertEq(bob.balance - bobBalanceBefore, 1 ether, "Bob should receive 1 ETH");
        console.log("Escrow released successfully");
    }

    function test_EscrowRelease_RevertsWhenConditionNotMet() public {
        console.log("\n=== Escrow Release: Condition NOT MET ===");

        int256 threshold = currentETHPrice + (100 * 10 ** 8);
        bytes memory data = abi.encode(ETH_USD_FEED, threshold, uint8(0), 3600);

        vm.prank(alice);
        uint256 id = escrow.createEscrow{value: 1 ether}(bob, address(resolver), data);

        vm.prank(bob);
        vm.expectRevert();
        escrow.release(id);

        console.log("Escrow release correctly reverted");
    }

    function test_EscrowRefund_ByDepositor() public {
        console.log("\n=== Escrow Refund ===");

        int256 threshold = currentETHPrice + (100 * 10 ** 8);
        bytes memory data = abi.encode(ETH_USD_FEED, threshold, uint8(0), 3600);

        vm.prank(alice);
        uint256 id = escrow.createEscrow{value: 1 ether}(bob, address(resolver), data);

        uint256 aliceBalanceBefore = alice.balance;

        vm.prank(alice);
        escrow.refund(id);

        assertEq(alice.balance - aliceBalanceBefore, 1 ether, "Alice should receive refund");
        console.log("Escrow refunded successfully");
    }
}
