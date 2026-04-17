// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Deploy} from "./Deploy.s.sol";
import {SimpleUnderwriterPolicy} from "../contracts/policies/SimpleUnderwriterPolicy.sol";

contract DeploySimpleUnderwriterPolicy is Deploy {
    function run() public override {
        uint256 deployerPrivateKey = getDeployerPrivateKey();

        vm.startBroadcast(deployerPrivateKey);

        SimpleUnderwriterPolicy policy = new SimpleUnderwriterPolicy();

        vm.stopBroadcast();

        logDeployment("SimpleUnderwriterPolicy", address(policy));
        saveDeployment("SimpleUnderwriterPolicy", address(policy));
    }
}
