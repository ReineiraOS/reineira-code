// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {TimeLockResolver} from "../contracts/resolvers/TimeLockResolver.sol";

/// @title DeployTimeLockResolver
/// @notice Deployment script for TimeLockResolver with role-based access control
/// @dev Run with: forge script script/DeployTimeLockResolver.s.sol --rpc-url arbitrum --broadcast --verify
contract DeployTimeLockResolver is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address protocolAddress = vm.envOr("PROTOCOL_ADDRESS", deployer);
        address complianceAddress = vm.envOr("COMPLIANCE_ADDRESS", deployer);

        vm.startBroadcast(deployerPrivateKey);

        TimeLockResolver resolver = new TimeLockResolver(deployer);
        resolver.grantProtocolRole(protocolAddress);
        resolver.grantComplianceRole(complianceAddress);

        console.log("TimeLockResolver deployed at:", address(resolver));
        console.log("Admin:", deployer);
        console.log("Protocol:", protocolAddress);
        console.log("Compliance:", complianceAddress);

        vm.stopBroadcast();
    }
}
