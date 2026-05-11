// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IConditionResolver} from "../interfaces/IConditionResolver.sol";
import {ReineiraAccessControl} from "../access/ReineiraAccessControl.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/// @title TimeLockResolver
/// @notice Simple time-based condition resolver.
/// @dev Releases escrow after a specified deadline. Inherits ReineiraAccessControl
///      for protocol-gated configuration and compliance pausability.
contract TimeLockResolver is IConditionResolver, ReineiraAccessControl {
    struct Config {
        uint256 deadline;
    }

    mapping(uint256 => Config) public configs;

    event ConditionSet(uint256 indexed escrowId, uint256 deadline);

    error InvalidDeadline();
    error ConditionAlreadySet();

    /// @param admin Initial admin address.
    constructor(address admin) ReineiraAccessControl(admin) {}

    /// @inheritdoc IConditionResolver
    /// @dev Restricted to PROTOCOL_ROLE and blocked when paused.
    function onConditionSet(uint256 escrowId, bytes calldata data) external onlyProtocol whenNotPaused {
        if (configs[escrowId].deadline != 0) revert ConditionAlreadySet();

        uint256 deadline = abi.decode(data, (uint256));
        if (deadline <= block.timestamp) revert InvalidDeadline();

        configs[escrowId] = Config({deadline: deadline});
        emit ConditionSet(escrowId, deadline);
    }

    /// @inheritdoc IConditionResolver
    /// @dev Returns false when paused (reverts via whenNotPaused modifier).
    function isConditionMet(uint256 escrowId) external view whenNotPaused returns (bool) {
        return block.timestamp >= configs[escrowId].deadline;
    }

    /// @notice ERC-165 interface detection.
    /// @param interfaceId Interface identifier.
    /// @return True if the contract implements the interface.
    function supportsInterface(bytes4 interfaceId) public view override(AccessControl) returns (bool) {
        return interfaceId == type(IConditionResolver).interfaceId || super.supportsInterface(interfaceId);
    }
}
