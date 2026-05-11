// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {ICCTPV2MessageTransmitter} from "../interfaces/ICCTPV2MessageTransmitter.sol";
import {IEscrow} from "../interfaces/IEscrow.sol";

/// @title CCTPV2EscrowReceiver
/// @notice Receives USDC via Circle CCTP V2 and forwards it to an escrow contract.
/// @dev Defense-in-depth: if the downstream escrow.fund call reverts after CCTP nonce
///      consumption, inbound USDC is trapped in this contract. Owner-only recover()
///      allows retrieval of stuck funds.
contract CCTPV2EscrowReceiver is Ownable {
    using SafeERC20 for IERC20;

    /// @notice The CCTP V2 MessageTransmitter contract
    ICCTPV2MessageTransmitter public immutable cctpV2Transmitter;

    /// @notice The escrow contract to forward funds to
    IEscrow public immutable escrow;

    /// @notice The USDC token contract
    IERC20 public immutable usdc;

    /// @notice Emitted when a CCTP message is successfully received and forwarded
    /// @param nonceHash Keccak256 hash of the CCTP message
    /// @param amount Amount of USDC forwarded
    /// @param escrowId The escrow ID funded
    event MessageReceived(bytes32 indexed nonceHash, uint256 amount, uint256 escrowId);

    /// @notice Emitted when owner recovers stuck tokens
    /// @param token The token recovered
    /// @param amount Amount recovered
    /// @param to Recipient address
    event Recovered(IERC20 indexed token, uint256 amount, address indexed to);

    /// @param cctpV2Transmitter_ Address of the CCTP V2 MessageTransmitter
    /// @param escrow_ Address of the escrow contract
    /// @param usdc_ Address of the USDC token
    /// @param initialOwner Address of the initial owner
    constructor(address cctpV2Transmitter_, address escrow_, address usdc_, address initialOwner)
        Ownable(initialOwner)
    {
        cctpV2Transmitter = ICCTPV2MessageTransmitter(cctpV2Transmitter_);
        escrow = IEscrow(escrow_);
        usdc = IERC20(usdc_);
    }

    /// @notice Receive a CCTP V2 message, extract USDC, and forward to escrow
    /// @param message The CCTP message bytes
    /// @param attestation The CCTP attestation bytes
    /// @param escrowId The ID of the escrow to fund
    /// @dev CCTP nonce is consumed on first receipt. If escrow.fund reverts,
    ///      funds remain in this contract and can only be recovered via recover().
    function receiveMessage(bytes calldata message, bytes calldata attestation, uint256 escrowId) external {
        bool success = cctpV2Transmitter.receiveMessage(message, attestation);
        require(success, "CCTP receive failed");

        uint256 balance = usdc.balanceOf(address(this));
        require(balance > 0, "No USDC received");

        // Forward to escrow. If this reverts, funds remain in this contract.
        // CCTP nonce is already consumed, so a retry will fail.
        usdc.safeTransfer(address(escrow), balance);
        escrow.fund(escrowId, balance);

        emit MessageReceived(keccak256(message), balance, escrowId);
    }

    /// @notice Owner-only recovery of stuck tokens
    /// @param token The ERC20 token to recover
    /// @param amount Amount to recover
    /// @param to Recipient address
    /// @dev Defense-in-depth for ESC-MN-01: funds stuck when downstream call reverts
    ///      after cctpV2Transmitter.receiveMessage succeeds.
    function recover(IERC20 token, uint256 amount, address to) external onlyOwner {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Zero amount");
        uint256 balance = token.balanceOf(address(this));
        require(amount <= balance, "Insufficient balance");
        token.safeTransfer(to, amount);
        emit Recovered(token, amount, to);
    }
}
