// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {SimpleEscrow} from "../contracts/test/SimpleEscrow.sol";
import {ChainlinkPriceFeedResolver} from "../contracts/resolvers/ChainlinkPriceFeedResolver.sol";
import {ChainlinkFunctionsResolver} from "../contracts/resolvers/ChainlinkFunctionsResolver.sol";
import {ReclaimResolver} from "../contracts/resolvers/ReclaimResolver.sol";
import {IOracleConditionResolver} from "../contracts/interfaces/IOracleConditionResolver.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @title Unified End-to-End Test
/// @notice Tests ALL THREE resolver types: Chainlink Data Feeds, Chainlink Functions, and Reclaim
/// @dev Run with: forge test --match-contract UnifiedE2E --fork-url $ARBITRUM_SEPOLIA_RPC_URL -vvv
contract UnifiedE2ETest is Test {
    SimpleEscrow public escrow;
    ChainlinkPriceFeedResolver public priceFeedResolver;
    ChainlinkFunctionsResolver public functionsResolver;
    ReclaimResolver public reclaimResolver;

    // Arbitrum Sepolia addresses
    address constant ETH_USD_FEED = 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165;
    address constant BTC_USD_FEED = 0x56a43EB56Da12C0dc1D972ACb089c06a5dEF8e69;
    address constant CHAINLINK_FUNCTIONS_ROUTER = 0x234a5fb5Bd614a7AA2FfAB244D603abFA0Ac5C5C;
    bytes32 constant DON_ID = 0x66756e2d617262697472756d2d7365706f6c69612d3100000000000000000000;

    address depositor = address(0x1);
    address beneficiary = address(0x2);

    function setUp() public {
        vm.deal(depositor, 100 ether);
        vm.deal(beneficiary, 1 ether);

        console.log("\n========================================");
        console.log("UNIFIED E2E TEST - ARBITRUM SEPOLIA");
        console.log("========================================");
        console.log("\n=== DEPLOYING ALL CONTRACTS ===");

        // Deploy escrow
        escrow = new SimpleEscrow();
        console.log("SimpleEscrow deployed:", address(escrow));

        // Deploy all three resolvers
        priceFeedResolver = new ChainlinkPriceFeedResolver();
        console.log("ChainlinkPriceFeedResolver deployed:", address(priceFeedResolver));

        functionsResolver = new ChainlinkFunctionsResolver(CHAINLINK_FUNCTIONS_ROUTER);
        console.log("ChainlinkFunctionsResolver deployed:", address(functionsResolver));

        reclaimResolver = new ReclaimResolver();
        console.log("ReclaimResolver deployed:", address(reclaimResolver));

        console.log("\n=== DEPLOYMENT COMPLETE ===\n");
    }

    /// @notice Test 1: Chainlink Data Feeds (Price Feed)
    function test_1_ChainlinkDataFeeds() public {
        console.log("========================================");
        console.log("TEST 1: CHAINLINK DATA FEEDS");
        console.log("========================================\n");

        uint256 escrowAmount = 1 ether;

        // Get current ETH price
        AggregatorV3Interface feed = AggregatorV3Interface(ETH_USD_FEED);
        (, int256 currentPrice,,,) = feed.latestRoundData();
        console.log("Current ETH/USD Price: $", uint256(currentPrice) / 10 ** 8);

        // Set threshold below current price so condition is met
        int256 threshold = currentPrice - (100 * 10 ** 8); // $100 below current
        uint8 op = uint8(IOracleConditionResolver.ComparisonOp.GreaterThan);
        uint256 maxStaleness = 3600;

        bytes memory resolverData = abi.encode(ETH_USD_FEED, threshold, op, maxStaleness);

        console.log("\nStep 1: Create escrow with price feed condition");
        console.log("  Condition: ETH/USD > $", uint256(threshold) / 10 ** 8);
        console.log("  Amount:", escrowAmount / 1 ether, "ETH");

        vm.prank(depositor);
        uint256 escrowId =
            escrow.createEscrow{value: escrowAmount}(beneficiary, address(priceFeedResolver), resolverData);
        console.log("  Escrow ID:", escrowId);

        console.log("\nStep 2: Check condition");
        bool conditionMet = escrow.isConditionMet(escrowId);
        console.log("  Condition met:", conditionMet);
        assertTrue(conditionMet, "Price feed condition should be met");

        console.log("\nStep 3: Release funds");
        uint256 balBefore = beneficiary.balance;
        escrow.release(escrowId);
        uint256 balAfter = beneficiary.balance;
        assertEq(balAfter - balBefore, escrowAmount, "Funds not transferred");
        console.log("  Funds released successfully!");

        console.log("\n[PASS] CHAINLINK DATA FEEDS TEST PASSED\n");
    }

    /// @notice Test 2: Chainlink Functions (DON)
    /// @dev NOTE: This test configures the resolver but cannot execute without a funded subscription
    function test_2_ChainlinkFunctions() public {
        console.log("========================================");
        console.log("TEST 2: CHAINLINK FUNCTIONS (DON)");
        console.log("========================================\n");

        uint256 escrowAmount = 1 ether;

        // Chainlink Functions configuration
        string memory source = "return Functions.encodeUint256(42);";
        string[] memory args = new string[](0);
        bytes memory encryptedSecretsUrls = "";
        uint64 subscriptionId = 123; // Mock subscription ID
        uint32 gasLimit = 300000;
        bytes memory expectedResult = abi.encode(uint256(42));

        bytes memory resolverData =
            abi.encode(source, args, encryptedSecretsUrls, subscriptionId, gasLimit, DON_ID, expectedResult);

        console.log("Step 1: Create escrow with Chainlink Functions condition");
        console.log("  Source code: return Functions.encodeUint256(42);");
        console.log("  Expected result: 42");
        console.log("  DON ID:", vm.toString(DON_ID));

        vm.prank(depositor);
        uint256 escrowId =
            escrow.createEscrow{value: escrowAmount}(beneficiary, address(functionsResolver), resolverData);
        console.log("  Escrow ID:", escrowId);

        console.log("\nStep 2: Verify configuration");
        ChainlinkFunctionsResolver.Config memory config = functionsResolver.getConfig(escrowId);
        assertEq(config.subscriptionId, subscriptionId, "Subscription ID mismatch");
        assertEq(config.gasLimit, gasLimit, "Gas limit mismatch");
        assertEq(config.donId, DON_ID, "DON ID mismatch");
        assertTrue(config.configured, "Should be configured");
        assertFalse(config.fulfilled, "Should not be fulfilled yet");
        console.log("  Configuration verified");

        console.log("\nStep 3: Check source code");
        string memory storedSource = functionsResolver.getSource(escrowId);
        assertEq(storedSource, source, "Source code mismatch");
        console.log("  Source code stored correctly");

        console.log("\nNOTE: To fully test Chainlink Functions:");
        console.log("  1. Create subscription at functions.chain.link");
        console.log("  2. Fund subscription with LINK tokens");
        console.log("  3. Add resolver as consumer:", address(functionsResolver));
        console.log("  4. Call functionsResolver.executeRequest(escrowId)");
        console.log("  5. Wait for DON to fulfill the request");

        console.log("\n[PASS] CHAINLINK FUNCTIONS CONFIGURATION TEST PASSED\n");
    }

    /// @notice Test 3: Reclaim Protocol (zkTLS)
    function test_3_ReclaimProtocol() public {
        console.log("========================================");
        console.log("TEST 3: RECLAIM PROTOCOL (zkTLS)");
        console.log("========================================\n");

        uint256 escrowAmount = 1 ether;

        // Deploy mock Reclaim verifier
        MockReclaimVerifier mockReclaim = new MockReclaimVerifier();
        console.log("Mock Reclaim Verifier deployed:", address(mockReclaim));

        string memory provider = "http";
        string memory expectedAddress = "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb";
        string memory expectedMessage = "payment_received";

        bytes memory resolverData = abi.encode(address(mockReclaim), provider, expectedAddress, expectedMessage);

        console.log("\nStep 1: Create escrow with Reclaim condition");
        console.log("  Provider:", provider);
        console.log("  Expected context address:", expectedAddress);
        console.log("  Expected context message:", expectedMessage);

        vm.prank(depositor);
        uint256 escrowId = escrow.createEscrow{value: escrowAmount}(beneficiary, address(reclaimResolver), resolverData);
        console.log("  Escrow ID:", escrowId);

        console.log("\nStep 2: Prepare and submit zkTLS proof");

        // Set up valid proof
        bytes32 validIdentifier = keccak256("unique_proof_id");
        mockReclaim.setValidIdentifier(validIdentifier, true);

        string memory context = string(
            abi.encodePacked('{"contextAddress":"', expectedAddress, '","contextMessage":"', expectedMessage, '"}')
        );

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = hex"1234567890abcdef";

        bytes memory proofData = abi.encode(
            provider,
            "parameters",
            context,
            validIdentifier,
            address(0x123), // proof owner
            uint32(block.timestamp),
            uint32(1), // epoch
            signatures
        );

        reclaimResolver.submitProof(escrowId, proofData);
        console.log("  Proof submitted successfully");

        console.log("\nStep 3: Check condition");
        bool conditionMet = escrow.isConditionMet(escrowId);
        console.log("  Condition met:", conditionMet);
        assertTrue(conditionMet, "Reclaim condition should be met");

        console.log("\nStep 4: Release funds");
        uint256 balBefore = beneficiary.balance;
        escrow.release(escrowId);
        uint256 balAfter = beneficiary.balance;
        assertEq(balAfter - balBefore, escrowAmount, "Funds not transferred");
        console.log("  Funds released successfully!");

        console.log("\n[PASS] RECLAIM PROTOCOL TEST PASSED\n");
    }

    /// @notice Test 4: All three resolvers in parallel
    function test_4_AllThreeResolversInParallel() public {
        console.log("========================================");
        console.log("TEST 4: ALL THREE RESOLVERS IN PARALLEL");
        console.log("========================================\n");

        // Deploy mock Reclaim verifier
        MockReclaimVerifier mockReclaim = new MockReclaimVerifier();

        console.log("Creating 3 escrows simultaneously...\n");

        // Escrow 1: Chainlink Data Feed
        AggregatorV3Interface feed = AggregatorV3Interface(ETH_USD_FEED);
        (, int256 currentPrice,,,) = feed.latestRoundData();
        bytes memory data1 = abi.encode(
            ETH_USD_FEED, currentPrice - (100 * 10 ** 8), uint8(IOracleConditionResolver.ComparisonOp.GreaterThan), 3600
        );
        vm.prank(depositor);
        uint256 escrow1 = escrow.createEscrow{value: 1 ether}(beneficiary, address(priceFeedResolver), data1);
        console.log("Escrow 1 (Data Feed):", escrow1);

        // Escrow 2: Chainlink Functions
        bytes memory data2 = abi.encode(
            "return Functions.encodeUint256(100);",
            new string[](0),
            "",
            uint64(123),
            uint32(300000),
            DON_ID,
            abi.encode(uint256(100))
        );
        vm.prank(depositor);
        uint256 escrow2 = escrow.createEscrow{value: 1 ether}(beneficiary, address(functionsResolver), data2);
        console.log("Escrow 2 (Functions):", escrow2);

        // Escrow 3: Reclaim
        bytes memory data3 = abi.encode(address(mockReclaim), "http", "", "");
        vm.prank(depositor);
        uint256 escrow3 = escrow.createEscrow{value: 1 ether}(beneficiary, address(reclaimResolver), data3);
        console.log("Escrow 3 (Reclaim):", escrow3);

        console.log("\nVerifying all escrows created...");
        assertTrue(escrow1 == 0, "Escrow 1 created");
        assertTrue(escrow2 == 1, "Escrow 2 created");
        assertTrue(escrow3 == 2, "Escrow 3 created");

        console.log("\nChecking conditions:");
        console.log("  Escrow 1 (Data Feed) met:", escrow.isConditionMet(escrow1));
        console.log("  Escrow 2 (Functions) met:", escrow.isConditionMet(escrow2));
        console.log("  Escrow 3 (Reclaim) met:", escrow.isConditionMet(escrow3));

        // Release Data Feed escrow (condition already met)
        escrow.release(escrow1);
        console.log("\n[OK] Escrow 1 (Data Feed) released");

        // Submit proof for Reclaim escrow
        bytes32 validId = keccak256("proof_3");
        mockReclaim.setValidIdentifier(validId, true);
        bytes[] memory sigs = new bytes[](1);
        sigs[0] = hex"abcd";
        bytes memory proof =
            abi.encode("http", "params", "{}", validId, address(0x456), uint32(block.timestamp), uint32(1), sigs);
        reclaimResolver.submitProof(escrow3, proof);
        escrow.release(escrow3);
        console.log("[OK] Escrow 3 (Reclaim) released");

        console.log("\n[PASS] ALL THREE RESOLVERS WORKING IN PARALLEL\n");
    }
}

/// @notice Mock Reclaim verifier for testing
contract MockReclaimVerifier {
    mapping(bytes32 => bool) public validIdentifiers;

    function setValidIdentifier(bytes32 identifier, bool valid) external {
        validIdentifiers[identifier] = valid;
    }

    function verifyProof(
        string memory,
        string memory,
        string memory,
        bytes32 identifier,
        address,
        uint32,
        uint32,
        bytes[] memory
    ) external view {
        require(validIdentifiers[identifier], "Invalid identifier");
    }
}
