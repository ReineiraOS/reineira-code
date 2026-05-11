// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ChainlinkFunctionsResolver} from "../contracts/resolvers/ChainlinkFunctionsResolver.sol";

/// @title DeployChainlinkFunctionsResolver
/// @notice Deployment script for ChainlinkFunctionsResolver with role-based access control
/// @dev Run with: forge script script/DeployChainlinkFunctionsResolver.s.sol --rpc-url arbitrum --broadcast --verify
contract DeployChainlinkFunctionsResolver is Script {
    address constant ARBITRUM_FUNCTIONS_ROUTER = 0x97083E831f8f0639C5A9507750e3C5EBAcb3C8e3;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address protocolAddress = vm.envOr("PROTOCOL_ADDRESS", deployer);
        address complianceAddress = vm.envOr("COMPLIANCE_ADDRESS", deployer);

        vm.startBroadcast(deployerPrivateKey);

        ChainlinkFunctionsResolver resolver = new ChainlinkFunctionsResolver(ARBITRUM_FUNCTIONS_ROUTER, deployer);
        resolver.grantProtocolRole(protocolAddress);
        resolver.grantComplianceRole(complianceAddress);

        console.log("ChainlinkFunctionsResolver deployed at:", address(resolver));
        console.log("Admin:", deployer);
        console.log("Protocol:", protocolAddress);
        console.log("Compliance:", complianceAddress);
        console.log("");
        console.log("=== Next Steps ===");
        console.log("1. Create a subscription at https://functions.chain.link");
        console.log("2. Fund your subscription with LINK tokens");
        console.log("3. Add this contract as a consumer:");
        console.log("   Consumer address:", address(resolver));
        console.log("");
        console.log("=== Network Configuration ===");
        console.log("Router:", ARBITRUM_FUNCTIONS_ROUTER);

        vm.stopBroadcast();
    }
}
