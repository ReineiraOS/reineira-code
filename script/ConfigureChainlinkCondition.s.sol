// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ChainlinkPriceFeedResolver} from "../contracts/resolvers/ChainlinkPriceFeedResolver.sol";
import {IOracleConditionResolver} from "../contracts/interfaces/IOracleConditionResolver.sol";

/// @title Configure Chainlink Condition
/// @notice Create a REAL on-chain transaction to configure a price condition
/// @dev Run with: forge script script/ConfigureChainlinkCondition.s.sol --rpc-url arbitrum_sepolia --broadcast
contract ConfigureChainlinkCondition is Script {
    // Deployed resolver on Arbitrum Sepolia
    ChainlinkPriceFeedResolver constant RESOLVER = ChainlinkPriceFeedResolver(0x49DDce54E0dCe041fE2ab3590515b640289cE2de);
    
    // Chainlink ETH/USD feed on Arbitrum Sepolia
    address constant ETH_USD_FEED = 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console.log("=== Configuring Chainlink Price Condition ===");
        console.log("Resolver:", address(RESOLVER));
        console.log("Feed:", ETH_USD_FEED);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // Configure escrow ID 1: Release when ETH > $2000
        uint256 escrowId = 1;
        int256 threshold = 2000 * 10 ** 8; // $2000 with 8 decimals
        uint8 op = uint8(IOracleConditionResolver.ComparisonOp.GreaterThan);
        uint256 maxStaleness = 3600; // 1 hour

        bytes memory configData = abi.encode(ETH_USD_FEED, threshold, op, maxStaleness);

        console.log("Configuring Escrow ID:", escrowId);
        console.log("Condition: ETH/USD > $2000");
        console.log("Max Staleness: 1 hour");
        console.log("");

        // This creates a REAL transaction!
        RESOLVER.onConditionSet(escrowId, configData);

        console.log("Condition configured!");
        console.log("");

        // Read back the configuration
        (int256 storedThreshold, IOracleConditionResolver.ComparisonOp storedOp) = RESOLVER.getThreshold(escrowId);
        (int256 currentPrice, uint256 timestamp) = RESOLVER.getLatestValue(escrowId);
        bool isMet = RESOLVER.isConditionMet(escrowId);

        console.log("=== Verification ===");
        console.log("Stored Threshold:", uint256(storedThreshold) / 10 ** 8);
        console.log("Current ETH Price:", uint256(currentPrice) / 10 ** 8);
        console.log("Last Updated:", timestamp);
        console.log("Condition Met:", isMet);

        vm.stopBroadcast();

        console.log("");
        console.log("=== Transaction Details ===");
        console.log("View on Arbiscan:");
        console.log("https://sepolia.arbiscan.io/address/0x49DDce54E0dCe041fE2ab3590515b640289cE2de");
    }
}
