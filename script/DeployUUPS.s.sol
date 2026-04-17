// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

/// @title DeployUUPS
/// @notice Deployment script for UUPS upgradeable contracts
/// @dev Use this for deploying upgradeable resolvers or policies
abstract contract DeployUUPS is Script {
    /// @notice Deploy a UUPS upgradeable contract
    /// @dev Override this function in your deployment script
    function run() public virtual;

    /// @notice Get the deployer private key from environment
    function getDeployerPrivateKey() internal view returns (uint256) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        require(deployerPrivateKey != 0, "PRIVATE_KEY not set in .env");
        return deployerPrivateKey;
    }

    /// @notice Deploy a UUPS proxy for a contract
    /// @param contractName Name of the implementation contract
    /// @param initializerData Encoded initializer function call
    /// @return proxy Address of the deployed proxy
    function deployUUPSProxy(
        string memory contractName,
        bytes memory initializerData
    ) internal returns (address proxy) {
        vm.startBroadcast(getDeployerPrivateKey());
        
        // Deploy UUPS proxy using OpenZeppelin Foundry Upgrades
        proxy = Upgrades.deployUUPSProxy(
            contractName,
            initializerData
        );
        
        vm.stopBroadcast();
        
        logDeployment(contractName, proxy);
        saveDeployment(contractName, proxy);
        
        return proxy;
    }

    /// @notice Upgrade a UUPS proxy to a new implementation
    /// @param proxyAddress Address of the existing proxy
    /// @param newContractName Name of the new implementation contract
    /// @param initializerData Encoded initializer function call for the upgrade
    function upgradeUUPSProxy(
        address proxyAddress,
        string memory newContractName,
        bytes memory initializerData
    ) internal {
        vm.startBroadcast(getDeployerPrivateKey());
        
        Upgrades.upgradeProxy(
            proxyAddress,
            newContractName,
            initializerData
        );
        
        vm.stopBroadcast();
        
        console2.log("\n=== Upgrade Complete ===");
        console2.log("Proxy:", proxyAddress);
        console2.log("New Implementation:", newContractName);
        console2.log("===========================\n");
    }

    /// @notice Save deployment to JSON file
    /// @param contractName Name of the deployed contract
    /// @param proxyAddress Address of the deployed proxy
    function saveDeployment(string memory contractName, address proxyAddress) internal {
        string memory network = getNetworkName();
        string memory deploymentPath = string.concat("deployments/", network, ".json");
        
        // Create deployment record
        string memory json = "deployment";
        vm.serializeString(json, "network", network);
        vm.serializeAddress(json, "proxy", proxyAddress);
        vm.serializeAddress(json, "deployer", vm.addr(getDeployerPrivateKey()));
        vm.serializeUint(json, "deployedAt", block.timestamp);
        vm.serializeString(json, "type", "UUPS");
        string memory finalJson = vm.serializeString(json, "contractName", contractName);
        
        // Write to file
        vm.writeJson(finalJson, deploymentPath, string.concat(".", contractName));
        
        console2.log("Deployment saved to:", deploymentPath);
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
    function logDeployment(string memory contractName, address proxyAddress) internal view {
        console2.log("\n=== UUPS Proxy Deployment Complete ===");
        console2.log("Contract:", contractName);
        console2.log("Proxy Address:", proxyAddress);
        console2.log("Network:", getNetworkName());
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", vm.addr(getDeployerPrivateKey()));
        console2.log("\nNext steps:");
        console2.log("  Verify:  forge verify-contract <proxy> <contract> --chain <network>");
        console2.log("  Attach:  Use the SDK to connect this contract to an escrow or insurance pool");
        console2.log("===========================\n");
    }
}
