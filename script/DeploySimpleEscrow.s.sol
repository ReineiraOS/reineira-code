// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {SimpleEscrow} from "../contracts/test/SimpleEscrow.sol";

/// @title Deploy SimpleEscrow
/// @notice Deploy the escrow contract for testing Chainlink integration
contract DeploySimpleEscrow is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        SimpleEscrow escrow = new SimpleEscrow();

        console.log("SimpleEscrow deployed at:", address(escrow));
        console.log("");
        console.log("Now you can create escrows with Chainlink conditions!");

        vm.stopBroadcast();
    }
}
