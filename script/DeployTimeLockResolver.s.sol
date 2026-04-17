// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Deploy} from "./Deploy.s.sol";
import {TimeLockResolver} from "../contracts/resolvers/TimeLockResolver.sol";

contract DeployTimeLockResolver is Deploy {
    function run() public override {
        uint256 deployerPrivateKey = getDeployerPrivateKey();

        vm.startBroadcast(deployerPrivateKey);

        TimeLockResolver resolver = new TimeLockResolver();

        vm.stopBroadcast();

        logDeployment("TimeLockResolver", address(resolver));
        saveDeployment("TimeLockResolver", address(resolver));
    }
}
