// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {SimpleEscrow} from "../contracts/test/SimpleEscrow.sol";
import {ChainlinkFunctionsResolver} from "../contracts/resolvers/ChainlinkFunctionsResolver.sol";

interface IFunctionsRouter {
    function addConsumer(uint64 subscriptionId, address consumer) external;
}

/// @title CreateChainlinkFunctionsEscrowOnly
/// @notice Create escrow with subscription 568 (don't execute yet)
/// @dev Run with: forge script script/CreateChainlinkFunctionsEscrowOnly.s.sol --rpc-url arbitrum_sepolia --broadcast
contract CreateChainlinkFunctionsEscrowOnly is Script {
    SimpleEscrow constant escrow = SimpleEscrow(0xAF4E10197Ed7b823c0ef2716431ADB69aB30Ce0D);
    ChainlinkFunctionsResolver constant functionsResolver =
        ChainlinkFunctionsResolver(0xEaec0247A15103845af146f8700826940A4B42A3);
    IFunctionsRouter constant router = IFunctionsRouter(0x234a5fb5Bd614a7AA2FfAB244D603abFA0Ac5C5C);

    bytes32 constant DON_ID = 0x66756e2d617262697472756d2d7365706f6c69612d3100000000000000000000;
    uint64 constant SUBSCRIPTION_ID = 568;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("\n========================================");
        console.log("CREATE CHAINLINK FUNCTIONS ESCROW");
        console.log("Subscription ID: 568");
        console.log("========================================");

        vm.startBroadcast(deployerPrivateKey);

        // Add resolver as consumer
        console.log("\nAdding resolver as consumer...");
        try router.addConsumer(SUBSCRIPTION_ID, address(functionsResolver)) {
            console.log("Consumer added!");
        } catch {
            console.log("Consumer already added or error");
        }

        // Create escrow
        string memory source = "return Functions.encodeUint256(42);";
        bytes memory resolverData =
            abi.encode(source, new string[](0), "", SUBSCRIPTION_ID, uint32(300000), DON_ID, abi.encode(uint256(42)));

        console.log("\nCreating escrow...");
        uint256 escrowId = escrow.createEscrow{value: 0.001 ether}(deployer, address(functionsResolver), resolverData);

        vm.stopBroadcast();

        console.log("\nEscrow created!");
        console.log("Escrow ID:", escrowId);
        console.log("\nNext: Execute request manually:");
        console.log("cast send", address(functionsResolver));
        console.log("  'executeRequest(uint256)'", escrowId);
        console.log("  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL");
        console.log("  --private-key $PRIVATE_KEY");
    }
}
