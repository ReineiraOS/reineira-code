// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/// @title ReineiraAccessControl
/// @notice Shared access control module for ReineiraOS plugin contracts.
/// @dev Provides role-based permissions with four roles:
///      - DEFAULT_ADMIN_ROLE: full system control, intended for multisig
///      - PROTOCOL_ROLE: authorized protocol contracts (ConfidentialEscrow, etc.)
///      - COMPLIANCE_ROLE: regulatory operations (pause, emergency stop)
///      - UPGRADE_ROLE: UUPS proxy upgrades
///
///      All roles except DEFAULT_ADMIN_ROLE are managed by DEFAULT_ADMIN_ROLE.
///      The deployer receives DEFAULT_ADMIN_ROLE at construction and should
///      transfer it to a multisig after deployment.
abstract contract ReineiraAccessControl is AccessControl, Pausable {
    /// @notice Role for protocol contracts authorized to configure conditions/policies.
    bytes32 public constant PROTOCOL_ROLE = keccak256("PROTOCOL_ROLE");

    /// @notice Role for compliance/regulatory operations (pause, emergency).
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");

    /// @notice Role for performing UUPS proxy upgrades.
    bytes32 public constant UPGRADE_ROLE = keccak256("UPGRADE_ROLE");

    /// @dev Revert when caller lacks PROTOCOL_ROLE.
    error CallerNotProtocol();

    /// @dev Revert when caller lacks COMPLIANCE_ROLE.
    error CallerNotCompliance();

    /// @dev Revert when caller lacks DEFAULT_ADMIN_ROLE.
    error CallerNotAdmin();

    /// @dev Revert when caller lacks UPGRADE_ROLE.
    error CallerNotUpgrader();

    /// @notice Emitted when a protocol address is granted or revoked.
    event ProtocolAddressSet(address indexed protocol, bool enabled);

    /// @notice Emitted when the contract is paused by compliance.
    event CompliancePaused(address indexed account);

    /// @notice Emitted when the contract is unpaused by compliance.
    event ComplianceUnpaused(address indexed account);

    /// @notice Restrict to PROTOCOL_ROLE holders.
    modifier onlyProtocol() {
        if (!hasRole(PROTOCOL_ROLE, msg.sender)) revert CallerNotProtocol();
        _;
    }

    /// @notice Restrict to COMPLIANCE_ROLE holders.
    modifier onlyCompliance() {
        if (!hasRole(COMPLIANCE_ROLE, msg.sender)) revert CallerNotCompliance();
        _;
    }

    /// @notice Restrict to DEFAULT_ADMIN_ROLE holders.
    modifier onlyAdmin() {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) revert CallerNotAdmin();
        _;
    }

    /// @notice Restrict to UPGRADE_ROLE holders.
    modifier onlyUpgrader() {
        if (!hasRole(UPGRADE_ROLE, msg.sender)) revert CallerNotUpgrader();
        _;
    }

    /// @param admin Initial admin address (should be transferred to multisig post-deploy).
    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _setRoleAdmin(PROTOCOL_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(COMPLIANCE_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(UPGRADE_ROLE, DEFAULT_ADMIN_ROLE);
    }

    /// @notice Pause the contract. Only compliance owner.
    /// @dev When paused, `isConditionMet` and `onConditionSet` revert.
    function pause() external onlyCompliance {
        _pause();
        emit CompliancePaused(msg.sender);
    }

    /// @notice Unpause the contract. Only compliance owner.
    function unpause() external onlyCompliance {
        _unpause();
        emit ComplianceUnpaused(msg.sender);
    }

    /// @notice Grant PROTOCOL_ROLE to a protocol contract.
    /// @param protocol Address to authorize.
    function grantProtocolRole(address protocol) external onlyAdmin {
        _grantRole(PROTOCOL_ROLE, protocol);
        emit ProtocolAddressSet(protocol, true);
    }

    /// @notice Revoke PROTOCOL_ROLE from a protocol contract.
    /// @param protocol Address to deauthorize.
    function revokeProtocolRole(address protocol) external onlyAdmin {
        _revokeRole(PROTOCOL_ROLE, protocol);
        emit ProtocolAddressSet(protocol, false);
    }

    /// @notice Grant COMPLIANCE_ROLE to an address.
    /// @param compliance Address to authorize for compliance operations.
    function grantComplianceRole(address compliance) external onlyAdmin {
        _grantRole(COMPLIANCE_ROLE, compliance);
    }

    /// @notice Revoke COMPLIANCE_ROLE from an address.
    /// @param compliance Address to deauthorize.
    function revokeComplianceRole(address compliance) external onlyAdmin {
        _revokeRole(COMPLIANCE_ROLE, compliance);
    }

    /// @notice Grant UPGRADE_ROLE to an address.
    /// @param upgrader Address to authorize for proxy upgrades.
    function grantUpgradeRole(address upgrader) external onlyAdmin {
        _grantRole(UPGRADE_ROLE, upgrader);
    }

    /// @notice Revoke UPGRADE_ROLE from an address.
    /// @param upgrader Address to deauthorize.
    function revokeUpgradeRole(address upgrader) external onlyAdmin {
        _revokeRole(UPGRADE_ROLE, upgrader);
    }
}
