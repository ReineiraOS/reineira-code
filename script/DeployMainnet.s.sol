// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {TimeLockResolver} from "../contracts/resolvers/TimeLockResolver.sol";
import {ChainlinkPriceFeedResolver} from "../contracts/resolvers/ChainlinkPriceFeedResolver.sol";
import {ChainlinkFunctionsResolver} from "../contracts/resolvers/ChainlinkFunctionsResolver.sol";
import {ReclaimResolver} from "../contracts/resolvers/ReclaimResolver.sol";

/// @title DeployMainnet
/// @notice Mainnet deployment script for all ReineiraOS canonical resolvers.
/// @dev Run with:
///   forge script script/DeployMainnet.s.sol --rpc-url arbitrum --broadcast --verify
///
/// Environment variables required:
///   PRIVATE_KEY        — deployer key (must be funded with ETH for gas)
///   PROTOCOL_ADDRESS   — ConfidentialEscrow contract address (granted PROTOCOL_ROLE)
///   COMPLIANCE_ADDRESS — compliance owner address (granted COMPLIANCE_ROLE)
///   MULTISIG_ADDRESS   — Gnosis Safe / multisig (granted DEFAULT_ADMIN_ROLE, deployer renounced)
///
/// After deployment:
///   1. Verify contracts on Arbiscan
///   2. Confirm protocol, compliance, and multisig roles are set correctly
///   3. Renounce deployer's DEFAULT_ADMIN_ROLE if not done automatically
contract DeployMainnet is Script {
    // Arbitrum One Chainlink Functions router
    address constant ARBITRUM_FUNCTIONS_ROUTER = 0x97083E831f8f0639C5A9507750e3C5EBAcb3C8e3;

    struct Deployment {
        string name;
        address addr;
    }

    Deployment[] public deployments;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address protocolAddress = vm.envAddress("PROTOCOL_ADDRESS");
        address complianceAddress = vm.envAddress("COMPLIANCE_ADDRESS");
        address multisigAddress = vm.envAddress("MULTISIG_ADDRESS");

        address deployer = vm.addr(deployerPrivateKey);

        console2.log("\n========================================");
        console2.log("  ReineiraOS Mainnet Deployment");
        console2.log("========================================");
        console2.log("Deployer:", deployer);
        console2.log("Protocol:", protocolAddress);
        console2.log("Compliance:", complianceAddress);
        console2.log("Multisig:", multisigAddress);
        console2.log("========================================\n");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy TimeLockResolver
        TimeLockResolver timeLock = new TimeLockResolver(deployer);
        _configureRoles(address(timeLock), protocolAddress, complianceAddress, multisigAddress);
        _save("TimeLockResolver", address(timeLock));

        // 2. Deploy ChainlinkPriceFeedResolver
        ChainlinkPriceFeedResolver priceFeed = new ChainlinkPriceFeedResolver(deployer);
        _configureRoles(address(priceFeed), protocolAddress, complianceAddress, multisigAddress);
        _save("ChainlinkPriceFeedResolver", address(priceFeed));

        // 3. Deploy ChainlinkFunctionsResolver
        ChainlinkFunctionsResolver functions = new ChainlinkFunctionsResolver(ARBITRUM_FUNCTIONS_ROUTER, deployer);
        _configureRoles(address(functions), protocolAddress, complianceAddress, multisigAddress);
        _save("ChainlinkFunctionsResolver", address(functions));

        // 4. Deploy ReclaimResolver
        ReclaimResolver reclaim = new ReclaimResolver(deployer);
        _configureRoles(address(reclaim), protocolAddress, complianceAddress, multisigAddress);
        _save("ReclaimResolver", address(reclaim));

        // 5. Renounce deployer admin role on all contracts (transfer to multisig)
        timeLock.renounceRole(timeLock.DEFAULT_ADMIN_ROLE(), deployer);
        priceFeed.renounceRole(priceFeed.DEFAULT_ADMIN_ROLE(), deployer);
        functions.renounceRole(functions.DEFAULT_ADMIN_ROLE(), deployer);
        reclaim.renounceRole(reclaim.DEFAULT_ADMIN_ROLE(), deployer);

        vm.stopBroadcast();

        console2.log("\n========================================");
        console2.log("  Deployment Complete");
        console2.log("========================================");
        for (uint256 i = 0; i < deployments.length; i++) {
            console2.log(deployments[i].name, "=>", deployments[i].addr);
        }
        console2.log("========================================");
        console2.log("\nNext steps:");
        console2.log("  1. Verify contracts on Arbiscan");
        console2.log("  2. Confirm multisig holds DEFAULT_ADMIN_ROLE");
        console2.log("  3. Confirm protocol holds PROTOCOL_ROLE");
        console2.log("  4. Confirm compliance holds COMPLIANCE_ROLE");
        console2.log("  5. Update deployment records in deployments/arbitrum.json");
        console2.log("\nArbiscan verification commands:");
        for (uint256 i = 0; i < deployments.length; i++) {
            console2.log(
                string.concat(
                    "  forge verify-contract ",
                    vm.toString(deployments[i].addr),
                    " ",
                    deployments[i].name,
                    " --chain arbitrum --etherscan-api-key $ETHERSCAN_API_KEY"
                )
            );
        }
    }

    function _configureRoles(
        address target,
        address protocol,
        address compliance,
        address multisig
    ) internal {
        (bool success, bytes memory data) = target.call(
            abi.encodeWithSignature("grantProtocolRole(address)", protocol)
        );
        require(success, "grantProtocolRole failed");

        (success, data) = target.call(abi.encodeWithSignature("grantComplianceRole(address)", compliance));
        require(success, "grantComplianceRole failed");

        (success, data) = target.call(
            abi.encodeWithSignature("grantRole(bytes32,address)", bytes32(0), multisig)
        );
        require(success, "grant admin to multisig failed");
    }

    function _save(string memory name, address addr) internal {
        deployments.push(Deployment(name, addr));

        string memory network = "arbitrum";
        string memory deploymentPath = string.concat("deployments/", network, ".json");

        string memory json = "deployment";
        vm.serializeString(json, "network", network);
        vm.serializeAddress(json, "address", addr);
        vm.serializeAddress(json, "deployer", msg.sender);
        vm.serializeUint(json, "deployedAt", block.timestamp);
        string memory finalJson = vm.serializeString(json, "contractName", name);

        try vm.writeJson(finalJson, deploymentPath, string.concat(".", name)) {
            console2.log("Saved deployment:", deploymentPath);
        } catch {
            console2.log("Note: Could not save deployment file (use --ffi flag if needed)");
        }
    }
}
