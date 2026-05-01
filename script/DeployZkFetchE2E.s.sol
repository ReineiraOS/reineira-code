// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Deploy} from "./Deploy.s.sol";
import {ReclaimResolver} from "../contracts/resolvers/ReclaimResolver.sol";
import {SimpleEscrow} from "../contracts/test/SimpleEscrow.sol";
import {ZkFetchVerifier} from "../contracts/test/ZkFetchVerifier.sol";
import {console2} from "forge-std/console2.sol";

/// @title DeployZkFetchE2E
/// @notice Deploy complete E2E test environment for zkFetch proofs
contract DeployZkFetchE2E is Deploy {
    function run() public override {
        uint256 deployerPrivateKey = getDeployerPrivateKey();
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy ZkFetch verifier (mock for testing)
        ZkFetchVerifier verifier = new ZkFetchVerifier();
        console2.log("ZkFetchVerifier deployed at:", address(verifier));

        // 2. Deploy ReclaimResolver
        ReclaimResolver resolver = new ReclaimResolver();
        console2.log("ReclaimResolver deployed at:", address(resolver));

        // 3. Deploy SimpleEscrow
        SimpleEscrow escrow = new SimpleEscrow();
        console2.log("SimpleEscrow deployed at:", address(escrow));

        // 4. Create a test escrow with zkFetch verifier
        bytes memory resolverConfig = abi.encode(
            address(verifier), // zkFetch verifier address
            "http", // Expected provider
            "", // No context address validation
            "" // No context message validation
        );

        uint256 escrowId = escrow.createEscrow{value: 0.001 ether}(
            deployer, // Beneficiary
            address(resolver),
            resolverConfig
        );

        vm.stopBroadcast();

        // Log deployment info
        console2.log("\n=== zkFetch E2E Test Deployment Complete ===");
        console2.log("Network:", getNetworkName());
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", deployer);
        console2.log("\nContracts:");
        console2.log("  ZkFetchVerifier:", address(verifier));
        console2.log("  ReclaimResolver:", address(resolver));
        console2.log("  SimpleEscrow:", address(escrow));
        console2.log("\nTest Escrow Created:");
        console2.log("  Escrow ID:", escrowId);
        console2.log("  Amount: 0.001 ETH");
        console2.log("  Beneficiary:", deployer);
        console2.log("\nNext Steps:");
        console2.log("  1. Run: node scripts/zkFetchE2ETest.js");
        console2.log("  2. This will:");
        console2.log("     - Generate real zkFetch proof from GitHub API");
        console2.log("     - Verify proof off-chain using Reclaim SDK");
        console2.log("     - Submit to resolver (mock verifier accepts it)");
        console2.log("     - Release escrow");
        console2.log("     - Verify funds received");
        console2.log("=========================================\n");

        // Save deployments
        saveDeployment("ZkFetchVerifier", address(verifier));
        saveDeployment("ReclaimResolver", address(resolver));
        saveDeployment("SimpleEscrow", address(escrow));
    }
}
