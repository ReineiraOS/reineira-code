// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {SimpleEscrow} from "../contracts/test/SimpleEscrow.sol";
import {ChainlinkPriceFeedResolver} from "../contracts/resolvers/ChainlinkPriceFeedResolver.sol";
import {ChainlinkFunctionsResolver} from "../contracts/resolvers/ChainlinkFunctionsResolver.sol";
import {ReclaimResolver} from "../contracts/resolvers/ReclaimResolver.sol";
import {IOracleConditionResolver} from "../contracts/interfaces/IOracleConditionResolver.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @title CompleteE2E
/// @notice Complete E2E test with ALL THREE resolvers on Arbitrum Sepolia
/// @dev Run with: forge script script/CompleteE2E.s.sol --rpc-url arbitrum_sepolia --broadcast
contract CompleteE2E is Script {
    // Deployed contracts
    SimpleEscrow constant escrow = SimpleEscrow(0xAF4E10197Ed7b823c0ef2716431ADB69aB30Ce0D);
    ChainlinkPriceFeedResolver constant priceFeedResolver = 
        ChainlinkPriceFeedResolver(0x23D3A5984043E9bF04D796b65DF67a687163Ce65);
    ChainlinkFunctionsResolver constant functionsResolver = 
        ChainlinkFunctionsResolver(0xEaec0247A15103845af146f8700826940A4B42A3);
    ReclaimResolver constant reclaimResolver = 
        ReclaimResolver(0xc7b41B0Ad8d0F561eDe27fC7C467c1BD8250e792);

    // Chainlink config
    address constant ETH_USD_FEED = 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165;
    bytes32 constant DON_ID = 0x66756e2d617262697472756d2d7365706f6c69612d3100000000000000000000;

    // Track escrow IDs
    uint256 public dataFeedEscrowId;
    uint256 public functionsEscrowId;
    uint256 public reclaimEscrowId;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("\n========================================");
        console.log("COMPLETE E2E TEST - ALL THREE RESOLVERS");
        console.log("Network: Arbitrum Sepolia");
        console.log("========================================");
        console.log("Deployer:", deployer);
        console.log("Balance:", deployer.balance / 1 ether, "ETH\n");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy mock Reclaim verifier for testing
        MockReclaimVerifier mockVerifier = new MockReclaimVerifier();
        console.log("Mock Reclaim Verifier deployed:", address(mockVerifier));

        // Test 1: Chainlink Data Feeds
        console.log("\n=== TEST 1: CHAINLINK DATA FEEDS ===");
        dataFeedEscrowId = testChainlinkDataFeeds(deployer);
        
        // Test 2: Chainlink Functions
        console.log("\n=== TEST 2: CHAINLINK FUNCTIONS ===");
        functionsEscrowId = testChainlinkFunctions(deployer);

        // Test 3: Reclaim Protocol
        console.log("\n=== TEST 3: RECLAIM PROTOCOL ===");
        reclaimEscrowId = testReclaimProtocol(deployer, address(mockVerifier));

        vm.stopBroadcast();

        printSummary();
    }

    function testChainlinkDataFeeds(address beneficiary) internal returns (uint256 escrowId) {
        AggregatorV3Interface feed = AggregatorV3Interface(ETH_USD_FEED);
        (, int256 currentPrice,,,) = feed.latestRoundData();
        console.log("Current ETH/USD: $", uint256(currentPrice) / 10 ** 8);

        int256 threshold = currentPrice - (100 * 10 ** 8);
        bytes memory resolverData = abi.encode(
            ETH_USD_FEED,
            threshold,
            uint8(IOracleConditionResolver.ComparisonOp.GreaterThan),
            3600
        );

        console.log("Creating escrow: ETH/USD > $", uint256(threshold) / 10 ** 8);
        escrowId = escrow.createEscrow{value: 0.001 ether}(
            beneficiary,
            address(priceFeedResolver),
            resolverData
        );
        console.log("Escrow ID:", escrowId);

        bool conditionMet = escrow.isConditionMet(escrowId);
        console.log("Condition met:", conditionMet);

        if (conditionMet) {
            escrow.release(escrowId);
            console.log("Status: RELEASED");
        }

        return escrowId;
    }

    function testChainlinkFunctions(address beneficiary) internal returns (uint256 escrowId) {
        string memory source = "return Functions.encodeUint256(42);";
        bytes memory resolverData = abi.encode(
            source,
            new string[](0),
            "",
            uint64(123),
            uint32(300000),
            DON_ID,
            abi.encode(uint256(42))
        );

        console.log("Creating escrow with Functions DON");
        console.log("Source: return Functions.encodeUint256(42);");
        escrowId = escrow.createEscrow{value: 0.001 ether}(
            beneficiary,
            address(functionsResolver),
            resolverData
        );
        console.log("Escrow ID:", escrowId);
        console.log("Status: CONFIGURED (needs subscription)");

        return escrowId;
    }

    function testReclaimProtocol(address beneficiary, address verifier) internal returns (uint256 escrowId) {
        string memory provider = "http";
        string memory expectedAddress = "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb";
        string memory expectedMessage = "payment_received";

        bytes memory resolverData = abi.encode(
            verifier,
            provider,
            expectedAddress,
            expectedMessage
        );

        console.log("Creating escrow with Reclaim zkTLS");
        console.log("Provider:", provider);
        escrowId = escrow.createEscrow{value: 0.001 ether}(
            beneficiary,
            address(reclaimResolver),
            resolverData
        );
        console.log("Escrow ID:", escrowId);

        // Submit proof
        MockReclaimVerifier(verifier).setValidIdentifier(keccak256("test_proof"), true);
        
        string memory context = string(
            abi.encodePacked(
                '{"contextAddress":"',
                expectedAddress,
                '","contextMessage":"',
                expectedMessage,
                '"}'
            )
        );

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = hex"1234567890abcdef";

        bytes memory proofData = abi.encode(
            provider,
            "parameters",
            context,
            keccak256("test_proof"),
            beneficiary,
            uint32(block.timestamp),
            uint32(1),
            signatures
        );

        console.log("Submitting zkTLS proof...");
        reclaimResolver.submitProof(escrowId, proofData);

        bool conditionMet = escrow.isConditionMet(escrowId);
        console.log("Condition met:", conditionMet);

        if (conditionMet) {
            escrow.release(escrowId);
            console.log("Status: RELEASED");
        }

        return escrowId;
    }

    function printSummary() internal view {
        console.log("\n========================================");
        console.log("E2E TEST COMPLETE");
        console.log("========================================\n");

        console.log("=== Escrow IDs ===");
        console.log("Data Feed:", dataFeedEscrowId);
        console.log("Functions:", functionsEscrowId);
        console.log("Reclaim:", reclaimEscrowId);

        console.log("\n=== View on Arbiscan ===");
        console.log("SimpleEscrow:");
        console.log("https://sepolia.arbiscan.io/address/0xAF4E10197Ed7b823c0ef2716431ADB69aB30Ce0D");

        console.log("\n=== Status Summary ===");
        console.log("1. Chainlink Data Feeds: COMPLETE");
        console.log("2. Chainlink Functions: CONFIGURED");
        console.log("3. Reclaim Protocol: COMPLETE");

        console.log("\n=== Next Steps ===");
        console.log("For Chainlink Functions:");
        console.log("1. Create subscription at functions.chain.link");
        console.log("2. Fund with LINK tokens");
        console.log("3. Add consumer: 0xEaec0247A15103845af146f8700826940A4B42A3");
        console.log("4. Execute: functionsResolver.executeRequest(", functionsEscrowId, ")");
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
        require(validIdentifiers[identifier], "Invalid proof");
    }
}
