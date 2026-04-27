// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ChainlinkPriceFeedResolver} from "../contracts/resolvers/ChainlinkPriceFeedResolver.sol";
import {IOracleConditionResolver} from "../contracts/interfaces/IOracleConditionResolver.sol";

/// @title Test ALL functions on deployed contract
/// @notice Call every function to prove it works on-chain
/// @dev Run with: forge script script/TestChainlinkLive.s.sol --rpc-url arbitrum_sepolia --broadcast
contract TestChainlinkLive is Script {
    ChainlinkPriceFeedResolver constant RESOLVER = ChainlinkPriceFeedResolver(0x49DDce54E0dCe041fE2ab3590515b640289cE2de);
    
    address constant ETH_USD_FEED = 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165;
    address constant BTC_USD_FEED = 0x56a43EB56Da12C0dc1D972ACb089c06a5dEF8e69;
    address constant LINK_USD_FEED = 0x0FB99723Aee6f420beAD13e6bBB79b7E6F034298;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console.log("========================================");
        console.log("  TESTING ALL FUNCTIONS ON LIVE CONTRACT");
        console.log("========================================");
        console.log("Contract:", address(RESOLVER));
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // Test 1: Configure multiple escrows with different conditions
        console.log("=== Test 1: Configure Multiple Escrows ===");
        
        // Escrow 2: ETH < $10,000 (should be true)
        uint256 escrow2 = 2;
        bytes memory data2 = abi.encode(
            ETH_USD_FEED,
            int256(10000 * 10 ** 8),
            uint8(IOracleConditionResolver.ComparisonOp.LessThan),
            uint256(3600)
        );
        RESOLVER.onConditionSet(escrow2, data2);
        console.log("Escrow 2: ETH < $10,000 configured");

        // Escrow 3: BTC > $50,000 (should be true)
        uint256 escrow3 = 3;
        bytes memory data3 = abi.encode(
            BTC_USD_FEED,
            int256(50000 * 10 ** 8),
            uint8(IOracleConditionResolver.ComparisonOp.GreaterThan),
            uint256(3600)
        );
        RESOLVER.onConditionSet(escrow3, data3);
        console.log("Escrow 3: BTC > $50,000 configured");

        // Escrow 4: LINK != $100 (should be true)
        uint256 escrow4 = 4;
        bytes memory data4 = abi.encode(
            LINK_USD_FEED,
            int256(100 * 10 ** 8),
            uint8(IOracleConditionResolver.ComparisonOp.NotEqual),
            uint256(3600)
        );
        RESOLVER.onConditionSet(escrow4, data4);
        console.log("Escrow 4: LINK != $100 configured");

        vm.stopBroadcast();

        console.log("");
        console.log("=== Test 2: Read All Escrow States ===");

        // Check escrow 1 (configured earlier)
        console.log("\nEscrow 1 (ETH > $2000):");
        testEscrow(1);

        console.log("\nEscrow 2 (ETH < $10,000):");
        testEscrow(2);

        console.log("\nEscrow 3 (BTC > $50,000):");
        testEscrow(3);

        console.log("\nEscrow 4 (LINK != $100):");
        testEscrow(4);

        console.log("");
        console.log("=== Test 3: Check Staleness ===");
        
        bool stale1 = RESOLVER.isStale(1);
        bool stale2 = RESOLVER.isStale(2);
        bool stale3 = RESOLVER.isStale(3);
        bool stale4 = RESOLVER.isStale(4);
        
        console.log("Escrow 1 stale:", stale1);
        console.log("Escrow 2 stale:", stale2);
        console.log("Escrow 3 stale:", stale3);
        console.log("Escrow 4 stale:", stale4);

        console.log("");
        console.log("=== Test 4: Get Feed Addresses ===");
        
        address feed1 = RESOLVER.getFeedAddress(1);
        address feed2 = RESOLVER.getFeedAddress(2);
        address feed3 = RESOLVER.getFeedAddress(3);
        address feed4 = RESOLVER.getFeedAddress(4);
        
        console.log("Escrow 1 feed:", feed1);
        console.log("Escrow 2 feed:", feed2);
        console.log("Escrow 3 feed:", feed3);
        console.log("Escrow 4 feed:", feed4);

        console.log("");
        console.log("=== Test 5: Check Interface Support ===");
        
        bytes4 conditionResolverInterface = type(IOracleConditionResolver).interfaceId;
        bool supportsInterface = RESOLVER.supportsInterface(conditionResolverInterface);
        console.log("Supports IOracleConditionResolver:", supportsInterface);

        console.log("");
        console.log("========================================");
        console.log("  ALL TESTS COMPLETE!");
        console.log("========================================");
        console.log("");
        console.log("View transactions at:");
        console.log("https://sepolia.arbiscan.io/address/0x49DDce54E0dCe041fE2ab3590515b640289cE2de");
    }

    function testEscrow(uint256 escrowId) internal view {
        // Get threshold and operator
        (int256 threshold, IOracleConditionResolver.ComparisonOp op) = RESOLVER.getThreshold(escrowId);
        
        // Get latest value
        (int256 value, uint256 timestamp) = RESOLVER.getLatestValue(escrowId);
        
        // Check if condition is met
        bool isMet = RESOLVER.isConditionMet(escrowId);
        
        // Get feed address
        address feed = RESOLVER.getFeedAddress(escrowId);
        
        string memory opStr = getOpString(op);
        
        console.log("  Feed:", feed);
        console.log("  Current Value:", uint256(value) / 10 ** 8);
        console.log("  Threshold:", uint256(threshold) / 10 ** 8);
        console.log("  Operator:", opStr);
        console.log("  Last Update:", timestamp);
        console.log("  Condition Met:", isMet);
    }

    function getOpString(IOracleConditionResolver.ComparisonOp op) internal pure returns (string memory) {
        if (op == IOracleConditionResolver.ComparisonOp.GreaterThan) return ">";
        if (op == IOracleConditionResolver.ComparisonOp.GreaterThanOrEqual) return ">=";
        if (op == IOracleConditionResolver.ComparisonOp.LessThan) return "<";
        if (op == IOracleConditionResolver.ComparisonOp.LessThanOrEqual) return "<=";
        if (op == IOracleConditionResolver.ComparisonOp.Equal) return "==";
        if (op == IOracleConditionResolver.ComparisonOp.NotEqual) return "!=";
        return "?";
    }
}
