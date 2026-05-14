// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ChainlinkFunctionsResolver} from "../contracts/resolvers/ChainlinkFunctionsResolver.sol";
import {SimpleEscrow} from "../contracts/test/SimpleEscrow.sol";

/// @title CheckAndRelease
/// @notice Check if Chainlink Functions fulfilled and release escrow
/// @dev Run with: forge script script/CheckAndRelease.s.sol --rpc-url arbitrum_sepolia --broadcast
contract CheckAndRelease is Script {
    ChainlinkFunctionsResolver constant functionsResolver =
        ChainlinkFunctionsResolver(0xEaec0247A15103845af146f8700826940A4B42A3);

    SimpleEscrow constant escrow = SimpleEscrow(0xAF4E10197Ed7b823c0ef2716431ADB69aB30Ce0D);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 escrowId = 5; // Chainlink Functions escrow

        console.log("\n========================================");
        console.log("CHECK CHAINLINK FUNCTIONS STATUS");
        console.log("========================================");
        console.log("Escrow ID:", escrowId);

        ChainlinkFunctionsResolver.Config memory config = functionsResolver.getConfig(escrowId);

        console.log("\nStatus:");
        console.log("  Configured:", config.configured);
        console.log("  Fulfilled:", config.fulfilled);
        console.log("  Last Request ID:", vm.toString(config.lastRequestId));

        bool conditionMet = escrow.isConditionMet(escrowId);
        console.log("  Condition Met:", conditionMet);

        if (config.fulfilled && conditionMet) {
            console.log("\nCondition is met! Releasing escrow...");

            vm.startBroadcast(deployerPrivateKey);
            escrow.release(escrowId);
            vm.stopBroadcast();

            console.log("Escrow released successfully!");
            console.log("\nView on Arbiscan:");
            console.log("https://sepolia.arbiscan.io/address/", address(escrow));
        } else if (config.fulfilled && !conditionMet) {
            console.log("\nFulfilled but condition NOT met (result mismatch)");
        } else {
            console.log("\nWaiting for DON to fulfill the request...");
            console.log("Check again in 1-2 minutes");
        }
    }
}
