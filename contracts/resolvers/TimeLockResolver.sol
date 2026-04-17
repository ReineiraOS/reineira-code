// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IConditionResolver} from "../interfaces/IConditionResolver.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

/// @title TimeLockResolver
/// @notice Simple time-based condition resolver for testing
/// @dev Releases escrow after a specified deadline
contract TimeLockResolver is IConditionResolver, ERC165 {
    struct Config {
        uint256 deadline;
    }

    mapping(uint256 => Config) public configs;

    event ConditionSet(uint256 indexed escrowId, uint256 deadline);

    error InvalidDeadline();
    error ConditionAlreadySet();

    /// @inheritdoc IConditionResolver
    function onConditionSet(uint256 escrowId, bytes calldata data) external {
        if (configs[escrowId].deadline != 0) revert ConditionAlreadySet();
        
        uint256 deadline = abi.decode(data, (uint256));
        if (deadline <= block.timestamp) revert InvalidDeadline();
        
        configs[escrowId] = Config({deadline: deadline});
        emit ConditionSet(escrowId, deadline);
    }

    /// @inheritdoc IConditionResolver
    function isConditionMet(uint256 escrowId) external view returns (bool) {
        return block.timestamp >= configs[escrowId].deadline;
    }

    /// @inheritdoc ERC165
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(IConditionResolver).interfaceId || super.supportsInterface(interfaceId);
    }
}
