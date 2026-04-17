// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

/// @title Deploy
/// @notice Base deployment script for ReineiraOS plugins
/// @dev Extend this contract to deploy your resolvers or policies
abstract contract Deploy is Script {
    /// @notice Deploy a contract to the configured network
    /// @dev Override this function in your deployment script
    function run() public virtual;

    /// @notice Get the deployer private key from environment
    function getDeployerPrivateKey() internal view returns (uint256) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        require(deployerPrivateKey != 0, "PRIVATE_KEY not set in .env");
        return deployerPrivateKey;
    }

    /// @notice Save deployment to JSON file
    /// @param contractName Name of the deployed contract
    /// @param contractAddress Address of the deployed contract
    function saveDeployment(string memory contractName, address contractAddress) internal {
        string memory network = getNetworkName();
        string memory deploymentPath = string.concat("deployments/", network, ".json");

        // Create deployment record
        string memory json = "deployment";
        vm.serializeString(json, "network", network);
        vm.serializeAddress(json, "address", contractAddress);
        vm.serializeAddress(json, "deployer", vm.addr(getDeployerPrivateKey()));
        vm.serializeUint(json, "deployedAt", block.timestamp);
        string memory finalJson = vm.serializeString(json, "contractName", contractName);

        // Try to write to file (may fail due to fs permissions in scripts)
        try vm.writeJson(finalJson, deploymentPath, string.concat(".", contractName)) {
            console2.log("Deployment saved to:", deploymentPath);
        } catch {
            console2.log("Note: Could not save deployment file (use --ffi flag if needed)");
        }
    }

    /// @notice Get network name from chain ID
    function getNetworkName() internal view returns (string memory) {
        uint256 chainId = block.chainid;
        if (chainId == 421614) return "arbitrumSepolia";
        if (chainId == 42161) return "arbitrum";
        if (chainId == 31337) return "localhost";
        return "unknown";
    }

    /// @notice Log deployment information
    function logDeployment(string memory contractName, address contractAddress) internal view {
        console2.log("\n=== Deployment Complete ===");
        console2.log("Contract:", contractName);
        console2.log("Address:", contractAddress);
        console2.log("Network:", getNetworkName());
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", vm.addr(getDeployerPrivateKey()));
        console2.log("\nNext steps:");
        console2.log("  Verify:  forge verify-contract <address> <contract> --chain <network>");
        console2.log("  Attach:  Use the SDK to connect this contract to an escrow or insurance pool");
        console2.log("===========================\n");
    }
}
