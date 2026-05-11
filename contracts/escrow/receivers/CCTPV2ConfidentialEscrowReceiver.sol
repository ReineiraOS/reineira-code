// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {ICCTPV2MessageTransmitter} from "../interfaces/ICCTPV2MessageTransmitter.sol";
import {IConfidentialEscrow} from "../interfaces/IConfidentialEscrow.sol";
import {IConfidentialUSDCWrapper} from "../interfaces/IConfidentialUSDCWrapper.sol";

contract CCTPV2ConfidentialEscrowReceiver is Ownable {
    using SafeERC20 for IERC20;

    ICCTPV2MessageTransmitter public immutable cctpV2Transmitter;
    IConfidentialEscrow public immutable escrow;
    IERC20 public immutable usdc;
    IConfidentialUSDCWrapper public immutable confidentialUsdc;

    event MessageReceived(bytes32 indexed nonceHash, uint256 amount, uint256 escrowId);
    event Recovered(IERC20 indexed token, uint256 amount, address indexed to);
    event ConfidentialUsdcRecovered(uint64 amount, address indexed to);

    constructor(
        address cctpV2Transmitter_,
        address escrow_,
        address usdc_,
        address confidentialUsdc_,
        address initialOwner
    ) Ownable(initialOwner) {
        cctpV2Transmitter = ICCTPV2MessageTransmitter(cctpV2Transmitter_);
        escrow = IConfidentialEscrow(escrow_);
        usdc = IERC20(usdc_);
        confidentialUsdc = IConfidentialUSDCWrapper(confidentialUsdc_);
    }

    function receiveMessage(bytes calldata message, bytes calldata attestation, uint256 escrowId) external {
        bool success = cctpV2Transmitter.receiveMessage(message, attestation);
        require(success, "CCTP receive failed");

        uint256 balance = usdc.balanceOf(address(this));
        require(balance > 0, "No USDC received");
        uint64 balance64 = uint64(balance);

        usdc.forceApprove(address(confidentialUsdc), balance);
        confidentialUsdc.wrap(balance64);
        escrow.fundFrom(escrowId, balance64, address(this));

        emit MessageReceived(keccak256(message), balance, escrowId);
    }

    function recover(IERC20 token, uint256 amount, address to) external onlyOwner {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Zero amount");
        uint256 balance = token.balanceOf(address(this));
        require(amount <= balance, "Insufficient balance");
        token.safeTransfer(to, amount);
        emit Recovered(token, amount, to);
    }

    function recoverConfidentialUsdc(uint64 amount, address to) external onlyOwner {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Zero amount");
        confidentialUsdc.unwrap(amount);
        uint256 plainAmount = uint256(amount);
        uint256 balance = usdc.balanceOf(address(this));
        require(plainAmount <= balance, "Insufficient plain balance after unwrap");
        usdc.safeTransfer(to, plainAmount);
        emit ConfidentialUsdcRecovered(amount, to);
        emit Recovered(usdc, plainAmount, to);
    }
}
