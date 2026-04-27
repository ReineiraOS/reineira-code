// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {SimpleEscrow} from "../contracts/test/SimpleEscrow.sol";
import {ChainlinkPriceFeedResolver} from "../contracts/resolvers/ChainlinkPriceFeedResolver.sol";
import {IOracleConditionResolver} from "../contracts/interfaces/IOracleConditionResolver.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @title Demo Chainlink Escrows On-Chain
/// @notice Deploy escrow system and create REAL escrows with Chainlink conditions
/// @dev Run with: forge script script/DemoChainlinkEscrows.s.sol --rpc-url arbitrum_sepolia --broadcast
contract DemoChainlinkEscrows is Script {
    address constant ETH_USD_FEED = 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165;
    address constant BTC_USD_FEED = 0x56a43EB56Da12C0dc1D972ACb089c06a5dEF8e69;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("========================================");
        console.log("  CHAINLINK ESCROW DEMO - LIVE ON-CHAIN");
        console.log("========================================");
        console.log("Deployer:", deployer);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy contracts
        console.log("Step 1: Deploying contracts...");
        ChainlinkPriceFeedResolver resolver = new ChainlinkPriceFeedResolver();
        SimpleEscrow escrow = new SimpleEscrow();
        
        console.log("Resolver:", address(resolver));
        console.log("Escrow:", address(escrow));
        console.log("");

        // Get current prices
        AggregatorV3Interface ethFeed = AggregatorV3Interface(ETH_USD_FEED);
        AggregatorV3Interface btcFeed = AggregatorV3Interface(BTC_USD_FEED);
        (, int256 ethPrice,,,) = ethFeed.latestRoundData();
        (, int256 btcPrice,,,) = btcFeed.latestRoundData();

        console.log("Current Prices:");
        console.log("  ETH/USD:", uint256(ethPrice) / 10 ** 8);
        console.log("  BTC/USD:", uint256(btcPrice) / 10 ** 8);
        console.log("");

        // 2. Create escrow that WILL release (condition already met)
        console.log("Step 2: Creating escrow with MET condition...");
        bytes memory metData = abi.encode(
            ETH_USD_FEED,
            ethPrice - (100 * 10 ** 8), // $100 below current
            uint8(IOracleConditionResolver.ComparisonOp.GreaterThan),
            3600
        );
        
        uint256 escrow1 = escrow.createEscrow{value: 0.001 ether}(
            deployer,
            address(resolver),
            metData
        );
        console.log("Escrow 1 created (ID:", escrow1, ")");
        console.log("  Amount: 0.001 ETH");
        console.log("  Condition: ETH >", (uint256(ethPrice) / 10 ** 8) - 100);
        console.log("  Status: READY TO RELEASE");
        console.log("");

        // 3. Create escrow that will NOT release yet (condition not met)
        console.log("Step 3: Creating escrow with UNMET condition...");
        bytes memory unmetData = abi.encode(
            ETH_USD_FEED,
            ethPrice + (500 * 10 ** 8), // $500 above current
            uint8(IOracleConditionResolver.ComparisonOp.GreaterThan),
            3600
        );
        
        uint256 escrow2 = escrow.createEscrow{value: 0.002 ether}(
            deployer,
            address(resolver),
            unmetData
        );
        console.log("Escrow 2 created (ID:", escrow2, ")");
        console.log("  Amount: 0.002 ETH");
        console.log("  Condition: ETH >", (uint256(ethPrice) / 10 ** 8) + 500);
        console.log("  Status: WAITING (needs ETH to rise)");
        console.log("");

        // 4. Create BTC escrow
        console.log("Step 4: Creating BTC escrow...");
        bytes memory btcData = abi.encode(
            BTC_USD_FEED,
            btcPrice - (1000 * 10 ** 8), // $1000 below current
            uint8(IOracleConditionResolver.ComparisonOp.GreaterThan),
            3600
        );
        
        uint256 escrow3 = escrow.createEscrow{value: 0.0015 ether}(
            deployer,
            address(resolver),
            btcData
        );
        console.log("Escrow 3 created (ID:", escrow3, ")");
        console.log("  Amount: 0.0015 ETH");
        console.log("  Condition: BTC >", (uint256(btcPrice) / 10 ** 8) - 1000);
        console.log("  Status: READY TO RELEASE");
        console.log("");

        // 5. RELEASE the escrows that are ready
        console.log("Step 5: Releasing escrows with met conditions...");
        
        bool canRelease1 = escrow.isConditionMet(escrow1);
        bool canRelease2 = escrow.isConditionMet(escrow2);
        bool canRelease3 = escrow.isConditionMet(escrow3);
        
        console.log("Escrow 1 can release:", canRelease1);
        console.log("Escrow 2 can release:", canRelease2);
        console.log("Escrow 3 can release:", canRelease3);
        console.log("");

        if (canRelease1) {
            escrow.release(escrow1);
            console.log("Escrow 1 RELEASED!");
        }
        
        if (canRelease3) {
            escrow.release(escrow3);
            console.log("Escrow 3 RELEASED!");
        }

        vm.stopBroadcast();

        console.log("");
        console.log("DEMO COMPLETE!");
        console.log("Check Arbiscan for escrow activity");
    }
}
