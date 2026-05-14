// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ChainlinkPriceFeedResolver} from "../contracts/resolvers/ChainlinkPriceFeedResolver.sol";

/// @title DeployChainlinkPriceFeedResolver
/// @notice Deployment script for ChainlinkPriceFeedResolver
/// @dev Run with: forge script script/DeployChainlinkPriceFeedResolver.s.sol --rpc-url arbitrum_sepolia --broadcast --verify
contract DeployChainlinkPriceFeedResolver is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        ChainlinkPriceFeedResolver resolver = new ChainlinkPriceFeedResolver();

        console.log("ChainlinkPriceFeedResolver deployed at:", address(resolver));
        console.log("");
        console.log("=== Chainlink Price Feed Addresses (Arbitrum Sepolia) ===");
        console.log("ETH/USD: 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165");
        console.log("BTC/USD: 0x56a43EB56Da12C0dc1D972ACb089c06a5dEF8e69");
        console.log("LINK/USD: 0x0FB99723Aee6f420beAD13e6bBB79b7E6F034298");
        console.log("");
        console.log("=== Example Configuration ===");
        console.log("Release escrow when ETH/USD > $2000:");
        console.log("feedAddress: 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165");
        console.log("threshold: 200000000000 (2000 * 10^8)");
        console.log("op: 0 (GreaterThan)");
        console.log("maxStaleness: 3600 (1 hour)");

        vm.stopBroadcast();
    }
}
