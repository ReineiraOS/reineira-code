// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

interface IFunctionsRouter {
    function createSubscription() external returns (uint64 subscriptionId);
    function addConsumer(uint64 subscriptionId, address consumer) external;
}

/// @title CreateChainlinkSubscription
/// @notice Create a new Chainlink Functions subscription
/// @dev Run with: forge script script/CreateChainlinkSubscription.s.sol --rpc-url arbitrum_sepolia --broadcast
contract CreateChainlinkSubscription is Script {
    IFunctionsRouter constant router = IFunctionsRouter(0x234a5fb5Bd614a7AA2FfAB244D603abFA0Ac5C5C);
    address constant functionsResolver = 0xEaec0247A15103845af146f8700826940A4B42A3;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("\n========================================");
        console.log("CREATE CHAINLINK FUNCTIONS SUBSCRIPTION");
        console.log("========================================");
        console.log("Deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Create subscription
        console.log("\nCreating subscription...");
        uint64 subscriptionId = router.createSubscription();
        console.log("Subscription ID:", subscriptionId);

        // Add resolver as consumer
        console.log("\nAdding resolver as consumer...");
        router.addConsumer(subscriptionId, functionsResolver);
        console.log("Consumer added:", functionsResolver);

        vm.stopBroadcast();

        console.log("\n========================================");
        console.log("SUBSCRIPTION CREATED!");
        console.log("========================================");
        console.log("\nSubscription ID:", subscriptionId);
        console.log("\nNext steps:");
        console.log("1. Fund subscription with LINK tokens");
        console.log("   Get LINK: https://faucets.chain.link/arbitrum-sepolia");
        console.log("   Or visit: https://functions.chain.link");
        console.log("2. Add this to your .env:");
        console.log("   CHAINLINK_SUBSCRIPTION_ID=", subscriptionId);
        console.log("3. Create escrow with this subscription ID");
    }
}
