// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ChainlinkFunctionsResolver} from "../contracts/resolvers/ChainlinkFunctionsResolver.sol";

/// @title DeployChainlinkFunctionsResolver
/// @notice Deployment script for ChainlinkFunctionsResolver
/// @dev Run with: forge script script/DeployChainlinkFunctionsResolver.s.sol --rpc-url arbitrum_sepolia --broadcast --verify
contract DeployChainlinkFunctionsResolver is Script {
    address constant ARBITRUM_SEPOLIA_ROUTER = 0x234a5fb5Bd614a7AA2FfAB244D603abFA0Ac5C5C;
    bytes32 constant ARBITRUM_SEPOLIA_DON_ID = 0x66756e2d617262697472756d2d7365706f6c69612d3100000000000000000000;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        ChainlinkFunctionsResolver resolver = new ChainlinkFunctionsResolver(ARBITRUM_SEPOLIA_ROUTER);

        console.log("ChainlinkFunctionsResolver deployed at:", address(resolver));
        console.log("");
        console.log("=== Next Steps ===");
        console.log("1. Create a subscription at https://functions.chain.link");
        console.log("2. Fund your subscription with LINK tokens");
        console.log("3. Add this contract as a consumer:");
        console.log("   Consumer address:", address(resolver));
        console.log("");
        console.log("=== Network Configuration ===");
        console.log("Router:", ARBITRUM_SEPOLIA_ROUTER);
        console.log("DON ID:", vm.toString(ARBITRUM_SEPOLIA_DON_ID));
        console.log("");
        console.log("=== Example JavaScript Source ===");
        console.log("// Fetch GitHub stars");
        console.log("const response = await Functions.makeHttpRequest({");
        console.log("  url: 'https://api.github.com/repos/ethereum/solidity'");
        console.log("});");
        console.log("const stars = response.data.stargazers_count;");
        console.log("return Functions.encodeUint256(stars);");

        vm.stopBroadcast();
    }
}
