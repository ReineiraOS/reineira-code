// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ReclaimResolver} from "../contracts/resolvers/ReclaimResolver.sol";

/// @title DeployReclaimResolver
/// @notice Deployment script for ReclaimResolver with role-based access control
/// @dev Run with: forge script script/DeployReclaimResolver.s.sol --rpc-url arbitrum --broadcast --verify
contract DeployReclaimResolver is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address protocolAddress = vm.envOr("PROTOCOL_ADDRESS", deployer);
        address complianceAddress = vm.envOr("COMPLIANCE_ADDRESS", deployer);

        vm.startBroadcast(deployerPrivateKey);

        ReclaimResolver resolver = new ReclaimResolver(deployer);
        resolver.grantProtocolRole(protocolAddress);
        resolver.grantComplianceRole(complianceAddress);

        console.log("ReclaimResolver deployed at:", address(resolver));
        console.log("Admin:", deployer);
        console.log("Protocol:", protocolAddress);
        console.log("Compliance:", complianceAddress);

        vm.stopBroadcast();
    }
}
