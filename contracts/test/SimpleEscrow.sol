// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IConditionResolver} from "../interfaces/IConditionResolver.sol";

/// @title SimpleEscrow
/// @notice Minimal escrow contract for testing resolvers on testnet
/// @dev NOT production-ready - for testing only
contract SimpleEscrow {
    struct Escrow {
        address depositor;
        address beneficiary;
        uint256 amount;
        address resolver;
        bool released;
        bool refunded;
    }

    mapping(uint256 => Escrow) public escrows;
    uint256 public nextEscrowId;

    event EscrowCreated(
        uint256 indexed escrowId,
        address indexed depositor,
        address indexed beneficiary,
        uint256 amount,
        address resolver
    );
    event EscrowReleased(uint256 indexed escrowId, address indexed beneficiary, uint256 amount);
    event EscrowRefunded(uint256 indexed escrowId, address indexed depositor, uint256 amount);

    error InsufficientValue();
    error EscrowNotFound();
    error ConditionNotMet();
    error AlreadyReleased();
    error AlreadyRefunded();
    error OnlyDepositor();

    /// @notice Create a new escrow with a condition resolver
    /// @param beneficiary Address that receives funds when condition is met
    /// @param resolver Address of the IConditionResolver contract
    /// @param resolverData Configuration data for the resolver
    /// @return escrowId The ID of the created escrow
    function createEscrow(
        address beneficiary,
        address resolver,
        bytes calldata resolverData
    ) external payable returns (uint256 escrowId) {
        if (msg.value == 0) revert InsufficientValue();

        escrowId = nextEscrowId++;
        
        escrows[escrowId] = Escrow({
            depositor: msg.sender,
            beneficiary: beneficiary,
            amount: msg.value,
            resolver: resolver,
            released: false,
            refunded: false
        });

        // Initialize the resolver
        IConditionResolver(resolver).onConditionSet(escrowId, resolverData);

        emit EscrowCreated(escrowId, msg.sender, beneficiary, msg.value, resolver);
    }

    /// @notice Release escrow to beneficiary if condition is met
    /// @param escrowId The ID of the escrow to release
    function release(uint256 escrowId) external {
        Escrow storage escrow = escrows[escrowId];
        
        if (escrow.amount == 0) revert EscrowNotFound();
        if (escrow.released) revert AlreadyReleased();
        if (escrow.refunded) revert AlreadyRefunded();
        
        // Check if condition is met
        if (!IConditionResolver(escrow.resolver).isConditionMet(escrowId)) {
            revert ConditionNotMet();
        }

        escrow.released = true;
        
        (bool success, ) = escrow.beneficiary.call{value: escrow.amount}("");
        require(success, "Transfer failed");

        emit EscrowReleased(escrowId, escrow.beneficiary, escrow.amount);
    }

    /// @notice Refund escrow to depositor (only by depositor, regardless of condition)
    /// @param escrowId The ID of the escrow to refund
    function refund(uint256 escrowId) external {
        Escrow storage escrow = escrows[escrowId];
        
        if (escrow.amount == 0) revert EscrowNotFound();
        if (msg.sender != escrow.depositor) revert OnlyDepositor();
        if (escrow.released) revert AlreadyReleased();
        if (escrow.refunded) revert AlreadyRefunded();

        escrow.refunded = true;
        
        (bool success, ) = escrow.depositor.call{value: escrow.amount}("");
        require(success, "Transfer failed");

        emit EscrowRefunded(escrowId, escrow.depositor, escrow.amount);
    }

    /// @notice Check if an escrow's condition is met
    /// @param escrowId The ID of the escrow to check
    /// @return True if the condition is met
    function isConditionMet(uint256 escrowId) external view returns (bool) {
        Escrow storage escrow = escrows[escrowId];
        if (escrow.amount == 0) revert EscrowNotFound();
        return IConditionResolver(escrow.resolver).isConditionMet(escrowId);
    }
}
