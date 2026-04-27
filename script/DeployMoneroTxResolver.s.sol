// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Deploy} from "./Deploy.s.sol";
import {MoneroTxResolver} from "../contracts/resolvers/MoneroTxResolver.sol";
import {console2} from "forge-std/console2.sol";

/// @title DeployMoneroTxResolver
/// @notice Deploy MoneroTxResolver for hookedMonero integration
contract DeployMoneroTxResolver is Deploy {
    function run() public override {
        uint256 deployerPrivateKey = getDeployerPrivateKey();
        address deployer = vm.addr(deployerPrivateKey);

        console2.log("Deploying MoneroTxResolver...");
        console2.log("Deployer:", deployer);
        console2.log("Network:", getNetworkName());
        console2.log("Chain ID:", block.chainid);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy MoneroTxResolver
        MoneroTxResolver resolver = new MoneroTxResolver();

        vm.stopBroadcast();

        console2.log("\n=== MoneroTxResolver Deployment Complete ===");
        console2.log("MoneroTxResolver:", address(resolver));
        console2.log("\nNext Steps:");
        console2.log("  1. Deploy ZkFetchVerifier (mock for testing)");
        console2.log("  2. Integrate with hookedMonero WrappedMonero contract");
        console2.log("  3. Test burn flow with zkTLS proofs");
        console2.log("  4. Deploy hookedMonero UI and test end-to-end");
        console2.log("=========================================\n");

        // Save deployment
        saveDeployment("MoneroTxResolver", address(resolver));
    }
}
