// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {CCTPV2EscrowReceiver} from "../../contracts/escrow/receivers/CCTPV2EscrowReceiver.sol";
import {ICCTPV2MessageTransmitter} from "../../contracts/escrow/interfaces/ICCTPV2MessageTransmitter.sol";
import {IEscrow} from "../../contracts/escrow/interfaces/IEscrow.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "mUSDC") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockCCTPV2MessageTransmitter is ICCTPV2MessageTransmitter {
    bool public shouldSucceed = true;

    function setShouldSucceed(bool _shouldSucceed) external {
        shouldSucceed = _shouldSucceed;
    }

    function receiveMessage(bytes calldata, bytes calldata) external view returns (bool success) {
        return shouldSucceed;
    }
}

contract MockEscrow is IEscrow {
    bool public shouldRevert = false;
    uint256 public lastEscrowId;
    uint256 public lastAmount;

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function fund(uint256 escrowId, uint256 amount) external {
        if (shouldRevert) revert("Escrow fund reverted");
        lastEscrowId = escrowId;
        lastAmount = amount;
    }
}

contract CCTPV2EscrowReceiverTest is Test {
    CCTPV2EscrowReceiver public receiver;
    MockCCTPV2MessageTransmitter public cctp;
    MockEscrow public escrow;
    MockUSDC public usdc;

    address public owner = address(0xABCD);
    address public nonOwner = address(0xBEEF);
    address public recipient = address(0xCAFE);

    function setUp() public {
        cctp = new MockCCTPV2MessageTransmitter();
        escrow = new MockEscrow();
        usdc = new MockUSDC();
        receiver = new CCTPV2EscrowReceiver(address(cctp), address(escrow), address(usdc), owner);
    }

    ////////////////////////////////////////////////////////////////
    // receiveMessage success path
    ////////////////////////////////////////////////////////////////

    function test_receiveMessage_success() public {
        uint256 amount = 1000e6;
        uint256 escrowId = 42;
        usdc.mint(address(receiver), amount);

        vm.prank(address(this));
        receiver.receiveMessage("", "", escrowId);

        assertEq(escrow.lastEscrowId(), escrowId);
        assertEq(escrow.lastAmount(), amount);
        assertEq(usdc.balanceOf(address(receiver)), 0);
    }

    function test_receiveMessage_emitsEvent() public {
        uint256 amount = 1000e6;
        uint256 escrowId = 42;
        usdc.mint(address(receiver), amount);

        bytes memory message = "test";
        vm.expectEmit(true, false, false, true);
        emit CCTPV2EscrowReceiver.MessageReceived(keccak256(message), amount, escrowId);

        receiver.receiveMessage(message, "", escrowId);
    }

    ////////////////////////////////////////////////////////////////
    // receiveMessage failure modes
    ////////////////////////////////////////////////////////////////

    function test_receiveMessage_revertsWhenCctpFails() public {
        cctp.setShouldSucceed(false);
        vm.expectRevert("CCTP receive failed");
        receiver.receiveMessage("", "", 1);
    }

    function test_receiveMessage_revertsWhenNoUsdc() public {
        vm.expectRevert("No USDC received");
        receiver.receiveMessage("", "", 1);
    }

    function test_receiveMessage_fundsStuckWhenEscrowReverts() public {
        uint256 amount = 1000e6;
        usdc.mint(address(receiver), amount);
        escrow.setShouldRevert(true);

        vm.expectRevert("Escrow fund reverted");
        receiver.receiveMessage("", "", 1);

        // Funds are now stuck in the receiver
        assertEq(usdc.balanceOf(address(receiver)), amount);
    }

    ////////////////////////////////////////////////////////////////
    // recover — owner-only
    ////////////////////////////////////////////////////////////////

    function test_recover_onlyOwner() public {
        uint256 amount = 1000e6;
        usdc.mint(address(receiver), amount);

        vm.prank(owner);
        receiver.recover(IERC20(address(usdc)), amount, recipient);

        assertEq(usdc.balanceOf(recipient), amount);
        assertEq(usdc.balanceOf(address(receiver)), 0);
    }

    function test_recover_revertsWhenNonOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        receiver.recover(IERC20(address(usdc)), 1, recipient);
    }

    function test_recover_revertsZeroAmount() public {
        vm.prank(owner);
        vm.expectRevert("Zero amount");
        receiver.recover(IERC20(address(usdc)), 0, recipient);
    }

    function test_recover_revertsInvalidRecipient() public {
        vm.prank(owner);
        vm.expectRevert("Invalid recipient");
        receiver.recover(IERC20(address(usdc)), 1, address(0));
    }

    function test_recover_revertsInsufficientBalance() public {
        vm.prank(owner);
        vm.expectRevert("Insufficient balance");
        receiver.recover(IERC20(address(usdc)), 1, recipient);
    }

    function test_recover_partialAmount() public {
        uint256 amount = 1000e6;
        usdc.mint(address(receiver), amount);

        uint256 recoverAmount = 400e6;
        vm.prank(owner);
        receiver.recover(IERC20(address(usdc)), recoverAmount, recipient);

        assertEq(usdc.balanceOf(recipient), recoverAmount);
        assertEq(usdc.balanceOf(address(receiver)), amount - recoverAmount);
    }

    function test_recover_emitsEvent() public {
        uint256 amount = 1000e6;
        usdc.mint(address(receiver), amount);

        vm.prank(owner);
        vm.expectEmit(true, false, true, true);
        emit CCTPV2EscrowReceiver.Recovered(IERC20(address(usdc)), amount, recipient);
        receiver.recover(IERC20(address(usdc)), amount, recipient);
    }

    function test_recover_arbitraryToken() public {
        MockUSDC otherToken = new MockUSDC();
        uint256 amount = 500e6;
        otherToken.mint(address(receiver), amount);

        vm.prank(owner);
        receiver.recover(IERC20(address(otherToken)), amount, recipient);

        assertEq(otherToken.balanceOf(recipient), amount);
    }

    ////////////////////////////////////////////////////////////////
    // end-to-end stuck-funds recovery
    ////////////////////////////////////////////////////////////////

    function test_recover_stuckFundsAfterEscrowRevert() public {
        uint256 amount = 1000e6;
        uint256 escrowId = 7;
        usdc.mint(address(receiver), amount);
        escrow.setShouldRevert(true);

        // simulate stuck funds
        vm.expectRevert("Escrow fund reverted");
        receiver.receiveMessage("", "", escrowId);

        assertEq(usdc.balanceOf(address(receiver)), amount);

        // owner recovers
        vm.prank(owner);
        receiver.recover(IERC20(address(usdc)), amount, recipient);

        assertEq(usdc.balanceOf(recipient), amount);
    }
}
