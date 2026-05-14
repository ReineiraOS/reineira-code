// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Deploy} from "./Deploy.s.sol";
import {ReclaimResolver} from "../contracts/resolvers/ReclaimResolver.sol";

/// @title DeployReclaimResolver
/// @notice Deployment script for ReclaimResolver on Arbitrum Sepolia
/// @dev Deploys the Reclaim Protocol zkTLS-based condition resolver
contract DeployReclaimResolver is Deploy {
    function run() public override {
        uint256 deployerPrivateKey = getDeployerPrivateKey();

        vm.startBroadcast(deployerPrivateKey);

        ReclaimResolver resolver = new ReclaimResolver();

        vm.stopBroadcast();

        logDeployment("ReclaimResolver", address(resolver));
        saveDeployment("ReclaimResolver", address(resolver));
    }
}
