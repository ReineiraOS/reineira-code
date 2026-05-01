// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {SimpleEscrow} from "../contracts/test/SimpleEscrow.sol";
import {ChainlinkPriceFeedResolver} from "../contracts/resolvers/ChainlinkPriceFeedResolver.sol";
import {IOracleConditionResolver} from "../contracts/interfaces/IOracleConditionResolver.sol";

/// @title Create Chainlink-Powered Escrow
/// @notice Create a REAL escrow that releases when ETH price condition is met
/// @dev Run with: forge script script/CreateChainlinkEscrow.s.sol --rpc-url arbitrum_sepolia --broadcast
contract CreateChainlinkEscrow is Script {
    // Deployed contracts on Arbitrum Sepolia
    address constant RESOLVER = 0x7eb4f1Ab119a4521AeBc31a11FF703D105B0FEFE;
    address constant ETH_USD_FEED = 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("========================================");
        console.log("  CREATE CHAINLINK-POWERED ESCROW");
        console.log("========================================");
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy SimpleEscrow
        SimpleEscrow escrow = new SimpleEscrow();
        console.log("Escrow contract:", address(escrow));
        console.log("");

        // Configure Chainlink condition: Release when ETH > $2000
        address beneficiary = deployer; // For demo, send back to yourself
        uint256 escrowAmount = 0.001 ether; // 0.001 ETH
        
        int256 threshold = 2000 * 10 ** 8; // $2000 with 8 decimals
        uint8 op = uint8(IOracleConditionResolver.ComparisonOp.GreaterThan);
        uint256 maxStaleness = 3600; // 1 hour

        bytes memory resolverData = abi.encode(ETH_USD_FEED, threshold, op, maxStaleness);

        console.log("Creating escrow with:");
        console.log("  Amount: 0.001 ETH");
        console.log("  Beneficiary:", beneficiary);
        console.log("  Condition: ETH/USD > $2000");
        console.log("  Resolver:", RESOLVER);
        console.log("");

        // Create the escrow
        uint256 escrowId = escrow.createEscrow{value: escrowAmount}(
            beneficiary,
            RESOLVER,
            resolverData
        );

        console.log("Escrow created! ID:", escrowId);
        console.log("");

        vm.stopBroadcast();

        // Check current state
        console.log("=== Current State ===");
        
        (address depositor, address ben, uint256 amount, address resolver, bool released, bool refunded) = 
            escrow.escrows(escrowId);
        
        console.log("Depositor:", depositor);
        console.log("Beneficiary:", ben);
        console.log("Amount:", amount);
        console.log("Resolver:", resolver);
        console.log("Released:", released);
        console.log("Refunded:", refunded);
        console.log("");

        // Check if condition is met
        bool conditionMet = escrow.isConditionMet(escrowId);
        console.log("Condition Met:", conditionMet);
        console.log("");

        // Get current ETH price
        ChainlinkPriceFeedResolver priceFeedResolver = ChainlinkPriceFeedResolver(RESOLVER);
        (int256 currentPrice,) = priceFeedResolver.getLatestValue(escrowId);
        console.log("Current ETH Price: $", uint256(currentPrice) / 10 ** 8);
        console.log("");

        if (conditionMet) {
            console.log("Condition is MET! You can call release() to claim funds");
            console.log("Command: cast send <escrow> release(uint256) <escrowId>");
        } else {
            console.log("Condition NOT met yet. Wait for ETH > $2000");
        }

        console.log("");
        console.log("Escrow deployed successfully!");
    }
}
