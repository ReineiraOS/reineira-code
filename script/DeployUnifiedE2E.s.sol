// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {SimpleEscrow} from "../contracts/test/SimpleEscrow.sol";
import {ChainlinkPriceFeedResolver} from "../contracts/resolvers/ChainlinkPriceFeedResolver.sol";
import {ChainlinkFunctionsResolver} from "../contracts/resolvers/ChainlinkFunctionsResolver.sol";
import {ReclaimResolver} from "../contracts/resolvers/ReclaimResolver.sol";

/// @title DeployUnifiedE2E
/// @notice Deploys all contracts for end-to-end testing on Arbitrum Sepolia
/// @dev Run with: forge script script/DeployUnifiedE2E.s.sol --rpc-url arbitrum_sepolia --broadcast --verify
contract DeployUnifiedE2E is Script {
    // Arbitrum Sepolia Chainlink Functions Router
    address constant CHAINLINK_FUNCTIONS_ROUTER = 0x234a5fb5Bd614a7AA2FfAB244D603abFA0Ac5C5C;
    bytes32 constant DON_ID = 0x66756e2d617262697472756d2d7365706f6c69612d3100000000000000000000;

    // Chainlink Price Feeds on Arbitrum Sepolia
    address constant ETH_USD_FEED = 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165;
    address constant BTC_USD_FEED = 0x56a43EB56Da12C0dc1D972ACb089c06a5dEF8e69;
    address constant LINK_USD_FEED = 0x0FB99723Aee6f420beAD13e6bBB79b7E6F034298;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("\n========================================");
        console.log("UNIFIED E2E DEPLOYMENT");
        console.log("Network: Arbitrum Sepolia");
        console.log("========================================");
        console.log("Deployer:", deployer);
        console.log("Balance:", deployer.balance / 1 ether, "ETH\n");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy SimpleEscrow
        console.log("=== Deploying SimpleEscrow ===");
        SimpleEscrow escrow = new SimpleEscrow();
        console.log("SimpleEscrow:", address(escrow));

        // Deploy ChainlinkPriceFeedResolver
        console.log("\n=== Deploying ChainlinkPriceFeedResolver ===");
        ChainlinkPriceFeedResolver priceFeedResolver = new ChainlinkPriceFeedResolver();
        console.log("ChainlinkPriceFeedResolver:", address(priceFeedResolver));

        // Deploy ChainlinkFunctionsResolver
        console.log("\n=== Deploying ChainlinkFunctionsResolver ===");
        ChainlinkFunctionsResolver functionsResolver = new ChainlinkFunctionsResolver(CHAINLINK_FUNCTIONS_ROUTER);
        console.log("ChainlinkFunctionsResolver:", address(functionsResolver));
        console.log("Router:", CHAINLINK_FUNCTIONS_ROUTER);
        console.log("DON ID:", vm.toString(DON_ID));

        // Deploy ReclaimResolver
        console.log("\n=== Deploying ReclaimResolver ===");
        ReclaimResolver reclaimResolver = new ReclaimResolver();
        console.log("ReclaimResolver:", address(reclaimResolver));

        vm.stopBroadcast();

        console.log("\n========================================");
        console.log("DEPLOYMENT COMPLETE");
        console.log("========================================\n");

        console.log("=== Contract Addresses ===");
        console.log("SimpleEscrow:", address(escrow));
        console.log("ChainlinkPriceFeedResolver:", address(priceFeedResolver));
        console.log("ChainlinkFunctionsResolver:", address(functionsResolver));
        console.log("ReclaimResolver:", address(reclaimResolver));

        console.log("\n=== Chainlink Price Feeds (Arbitrum Sepolia) ===");
        console.log("ETH/USD:", ETH_USD_FEED);
        console.log("BTC/USD:", BTC_USD_FEED);
        console.log("LINK/USD:", LINK_USD_FEED);

        console.log("\n=== Next Steps ===");
        console.log("\n1. CHAINLINK DATA FEEDS:");
        console.log("   - Ready to use immediately");
        console.log("   - Use price feeds above in escrow conditions");

        console.log("\n2. CHAINLINK FUNCTIONS:");
        console.log("   - Create subscription at https://functions.chain.link");
        console.log("   - Fund subscription with LINK tokens");
        console.log("   - Add consumer:", address(functionsResolver));
        console.log("   - Get LINK from https://faucets.chain.link/arbitrum-sepolia");

        console.log("\n3. RECLAIM PROTOCOL:");
        console.log("   - Get Reclaim verifier address from https://dev.reclaimprotocol.org/");
        console.log("   - Or deploy your own verifier contract");
        console.log("   - Generate proofs using Reclaim SDK");

        console.log("\n=== Example: Create Escrow with Price Feed ===");
        console.log("// Condition: ETH/USD > $2000");
        console.log("bytes memory data = abi.encode(");
        console.log("    0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165, // ETH/USD feed");
        console.log("    2000 * 10**8,  // threshold: $2000");
        console.log("    0,             // op: GreaterThan");
        console.log("    3600           // maxStaleness: 1 hour");
        console.log(");");
        console.log("escrow.createEscrow{value: 1 ether}(");
        console.log("    beneficiary,");
        console.log("    address(priceFeedResolver),");
        console.log("    data");
        console.log(");\n");
    }
}
