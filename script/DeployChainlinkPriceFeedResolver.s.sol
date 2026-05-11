// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ChainlinkPriceFeedResolver} from "../contracts/resolvers/ChainlinkPriceFeedResolver.sol";

/// @title DeployChainlinkPriceFeedResolver
/// @notice Deployment script for ChainlinkPriceFeedResolver with role-based access control
/// @dev Run with: forge script script/DeployChainlinkPriceFeedResolver.s.sol --rpc-url arbitrum --broadcast --verify
contract DeployChainlinkPriceFeedResolver is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address protocolAddress = vm.envOr("PROTOCOL_ADDRESS", deployer);
        address complianceAddress = vm.envOr("COMPLIANCE_ADDRESS", deployer);

        vm.startBroadcast(deployerPrivateKey);

        ChainlinkPriceFeedResolver resolver = new ChainlinkPriceFeedResolver(deployer);
        resolver.grantProtocolRole(protocolAddress);
        resolver.grantComplianceRole(complianceAddress);

        console.log("ChainlinkPriceFeedResolver deployed at:", address(resolver));
        console.log("Admin:", deployer);
        console.log("Protocol:", protocolAddress);
        console.log("Compliance:", complianceAddress);
        console.log("");
        console.log("=== Chainlink Price Feed Addresses (Arbitrum Mainnet) ===");
        console.log("ETH/USD: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612");
        console.log("BTC/USD: 0x6ce185860a4963106506C203335A2910413708e9");
        console.log("LINK/USD: 0x86E53CF1B870786351Da77A57575e79CB55812CB");
        console.log("");
        console.log("=== Example Configuration ===");
        console.log("Release escrow when ETH/USD > $2000:");
        console.log("feedAddress: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612");
        console.log("threshold: 200000000000 (2000 * 10^8)");
        console.log("op: 0 (GreaterThan)");
        console.log("maxStaleness: 3600 (1 hour)");

        vm.stopBroadcast();
    }
}
