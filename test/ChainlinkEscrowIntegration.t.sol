// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {SimpleEscrow} from "../contracts/test/SimpleEscrow.sol";
import {ChainlinkPriceFeedResolver} from "../contracts/resolvers/ChainlinkPriceFeedResolver.sol";
import {IOracleConditionResolver} from "../contracts/interfaces/IOracleConditionResolver.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @title Chainlink Escrow Integration Test
/// @notice END-TO-END test: Deploy everything, create escrow, test full lifecycle
/// @dev Run with: forge test --match-contract ChainlinkEscrowIntegration --fork-url $ARBITRUM_SEPOLIA_RPC_URL -vvv
contract ChainlinkEscrowIntegrationTest is Test {
    SimpleEscrow public escrow;
    ChainlinkPriceFeedResolver public resolver;

    address constant ETH_USD_FEED = 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165;
    address constant BTC_USD_FEED = 0x56a43EB56Da12C0dc1D972ACb089c06a5dEF8e69;

    address depositor = address(0x1);
    address beneficiary = address(0x2);

    function setUp() public {
        vm.deal(depositor, 10 ether);
        vm.deal(beneficiary, 1 ether);

        console.log("\n=== DEPLOYING CONTRACTS ===");

        // Deploy resolver
        resolver = new ChainlinkPriceFeedResolver();
        console.log("Resolver deployed:", address(resolver));

        // Deploy escrow
        escrow = new SimpleEscrow();
        console.log("Escrow deployed:", address(escrow));
    }

    /// @notice Full lifecycle test: Create escrow, check condition, release funds
    function test_FullEscrowLifecycle_ETHPrice() public {
        console.log("\n=== TEST: Full Escrow Lifecycle ===");

        uint256 escrowAmount = 1 ether;

        // Get current ETH price first
        AggregatorV3Interface feed = AggregatorV3Interface(ETH_USD_FEED);
        (, int256 currentPrice,,,) = feed.latestRoundData();
        console.log("Current ETH Price:", uint256(currentPrice) / 10 ** 8);

        // Set threshold below current price so condition is met
        int256 threshold = currentPrice - (100 * 10 ** 8); // $100 below current
        uint8 op = uint8(IOracleConditionResolver.ComparisonOp.GreaterThan);
        uint256 maxStaleness = 3600;

        bytes memory resolverData = abi.encode(ETH_USD_FEED, threshold, op, maxStaleness);

        console.log("\nStep 1: Create escrow");
        console.log("  Amount:", escrowAmount);
        console.log("  Depositor:", depositor);
        console.log("  Beneficiary:", beneficiary);
        console.log("  Condition: ETH >", uint256(threshold) / 10 ** 8);

        // Create escrow
        vm.prank(depositor);
        uint256 escrowId = escrow.createEscrow{value: escrowAmount}(beneficiary, address(resolver), resolverData);

        console.log("  Escrow ID:", escrowId);

        // Verify escrow state
        (address dep, address ben, uint256 amount, address res, bool released, bool refunded) = escrow.escrows(escrowId);

        assertEq(dep, depositor, "Depositor mismatch");
        assertEq(ben, beneficiary, "Beneficiary mismatch");
        assertEq(amount, escrowAmount, "Amount mismatch");
        assertEq(res, address(resolver), "Resolver mismatch");
        assertFalse(released, "Should not be released yet");
        assertFalse(refunded, "Should not be refunded");

        console.log("\nStep 2: Check condition");
        bool conditionMet = escrow.isConditionMet(escrowId);
        console.log("  Condition met:", conditionMet);
        assertTrue(conditionMet, "Condition should be met");

        // Check resolver details
        (int256 storedThreshold, IOracleConditionResolver.ComparisonOp storedOp) = resolver.getThreshold(escrowId);
        (int256 latestValue, uint256 timestamp) = resolver.getLatestValue(escrowId);

        console.log("  Latest value:", uint256(latestValue) / 10 ** 8);
        console.log("  Threshold:", uint256(storedThreshold) / 10 ** 8);
        console.log("  Last update:", timestamp);

        console.log("\nStep 3: Release funds");
        uint256 balBefore = beneficiary.balance;
        escrow.release(escrowId);
        uint256 balAfter = beneficiary.balance;
        assertEq(balAfter - balBefore, 1 ether, "Funds not transferred");
        console.log("  Funds transferred successfully");

        console.log("\nSUCCESS: Full lifecycle completed!");
    }

    /// @notice Test escrow with condition NOT met
    function test_EscrowConditionNotMet() public {
        console.log("\n=== TEST: Condition Not Met ===");

        // Set threshold way above current price
        int256 threshold = 1000000 * 10 ** 8; // $1 million
        uint8 op = uint8(IOracleConditionResolver.ComparisonOp.GreaterThan);
        uint256 maxStaleness = 3600;

        bytes memory resolverData = abi.encode(ETH_USD_FEED, threshold, op, maxStaleness);

        vm.prank(depositor);
        uint256 escrowId = escrow.createEscrow{value: 1 ether}(beneficiary, address(resolver), resolverData);

        console.log("Escrow ID:", escrowId);
        console.log("Condition: ETH > $1,000,000");

        bool conditionMet = escrow.isConditionMet(escrowId);
        console.log("Condition met:", conditionMet);
        assertFalse(conditionMet, "Condition should NOT be met");

        // Try to release - should fail
        vm.expectRevert(SimpleEscrow.ConditionNotMet.selector);
        escrow.release(escrowId);

        console.log("SUCCESS: Release correctly blocked when condition not met");
    }

    /// @notice Test multiple escrows with different conditions
    function test_MultipleEscrows() public {
        console.log("\n=== TEST: Multiple Escrows ===");

        // Get current prices
        AggregatorV3Interface ethFeed = AggregatorV3Interface(ETH_USD_FEED);
        AggregatorV3Interface btcFeed = AggregatorV3Interface(BTC_USD_FEED);

        (, int256 ethPrice,,,) = ethFeed.latestRoundData();
        (, int256 btcPrice,,,) = btcFeed.latestRoundData();

        console.log("Current ETH Price:", uint256(ethPrice) / 10 ** 8);
        console.log("Current BTC Price:", uint256(btcPrice) / 10 ** 8);

        // Escrow 1: ETH > (current - 100)
        bytes memory data1 = abi.encode(
            ETH_USD_FEED, ethPrice - (100 * 10 ** 8), uint8(IOracleConditionResolver.ComparisonOp.GreaterThan), 3600
        );

        vm.prank(depositor);
        uint256 escrow1 = escrow.createEscrow{value: 0.5 ether}(beneficiary, address(resolver), data1);

        // Escrow 2: BTC < (current + 1000)
        bytes memory data2 = abi.encode(
            BTC_USD_FEED, btcPrice + (1000 * 10 ** 8), uint8(IOracleConditionResolver.ComparisonOp.LessThan), 3600
        );

        vm.prank(depositor);
        uint256 escrow2 = escrow.createEscrow{value: 0.5 ether}(beneficiary, address(resolver), data2);

        console.log("\nEscrow 1 (ETH):", escrow1);
        console.log("  Condition met:", escrow.isConditionMet(escrow1));
        assertTrue(escrow.isConditionMet(escrow1), "ETH escrow should be met");

        console.log("\nEscrow 2 (BTC):", escrow2);
        console.log("  Condition met:", escrow.isConditionMet(escrow2));
        assertTrue(escrow.isConditionMet(escrow2), "BTC escrow should be met");

        // Release both
        escrow.release(escrow1);
        escrow.release(escrow2);

        console.log("\nSUCCESS: Multiple escrows handled correctly");
    }

    /// @notice Test staleness protection
    function test_StalenessProtection() public {
        console.log("\n=== TEST: Staleness Protection ===");

        // Set very short staleness window (1 second)
        bytes memory resolverData = abi.encode(
            ETH_USD_FEED,
            100 * 10 ** 8,
            uint8(IOracleConditionResolver.ComparisonOp.GreaterThan),
            1 // 1 second staleness
        );

        vm.prank(depositor);
        uint256 escrowId = escrow.createEscrow{value: 1 ether}(beneficiary, address(resolver), resolverData);

        // Check staleness
        bool isStale = resolver.isStale(escrowId);
        console.log("Is stale (1 second threshold):", isStale);
        assertTrue(isStale, "Data should be stale with 1 second threshold");

        // Condition should be false when stale
        bool conditionMet = escrow.isConditionMet(escrowId);
        console.log("Condition met (when stale):", conditionMet);
        assertFalse(conditionMet, "Condition should be false when data is stale");

        console.log("SUCCESS: Staleness protection working");
    }

    /// @notice Test refund functionality
    function test_RefundEscrow() public {
        console.log("\n=== TEST: Refund Escrow ===");

        bytes memory resolverData =
            abi.encode(ETH_USD_FEED, 100 * 10 ** 8, uint8(IOracleConditionResolver.ComparisonOp.GreaterThan), 3600);

        vm.prank(depositor);
        uint256 escrowId = escrow.createEscrow{value: 1 ether}(beneficiary, address(resolver), resolverData);

        uint256 depositorBalanceBefore = depositor.balance;

        // Depositor can refund anytime
        vm.prank(depositor);
        escrow.refund(escrowId);

        uint256 depositorBalanceAfter = depositor.balance;
        console.log("Depositor balance before:", depositorBalanceBefore);
        console.log("Depositor balance after:", depositorBalanceAfter);

        assertEq(depositorBalanceAfter - depositorBalanceBefore, 1 ether, "Refund failed");

        console.log("SUCCESS: Refund working");
    }

    /// @notice Test all comparison operators
    function test_AllComparisonOperators() public {
        console.log("\n=== TEST: All Comparison Operators ===");

        AggregatorV3Interface feed = AggregatorV3Interface(ETH_USD_FEED);
        (, int256 currentPrice,,,) = feed.latestRoundData();
        console.log("Current ETH Price:", uint256(currentPrice) / 10 ** 8);

        // Test GreaterThan
        {
            bytes memory data = abi.encode(ETH_USD_FEED, currentPrice - (100 * 10 ** 8), uint8(0), 3600);
            vm.prank(depositor);
            uint256 id = escrow.createEscrow{value: 0.1 ether}(beneficiary, address(resolver), data);
            assertTrue(escrow.isConditionMet(id), "GreaterThan failed");
            console.log("GreaterThan: PASS");
        }

        // Test LessThan
        {
            bytes memory data = abi.encode(ETH_USD_FEED, currentPrice + (100 * 10 ** 8), uint8(2), 3600);
            vm.prank(depositor);
            uint256 id = escrow.createEscrow{value: 0.1 ether}(beneficiary, address(resolver), data);
            assertTrue(escrow.isConditionMet(id), "LessThan failed");
            console.log("LessThan: PASS");
        }

        // Test NotEqual
        {
            bytes memory data = abi.encode(ETH_USD_FEED, currentPrice + 1, uint8(5), 3600);
            vm.prank(depositor);
            uint256 id = escrow.createEscrow{value: 0.1 ether}(beneficiary, address(resolver), data);
            assertTrue(escrow.isConditionMet(id), "NotEqual failed");
            console.log("NotEqual: PASS");
        }

        console.log("\nSUCCESS: All operators working");
    }
}
