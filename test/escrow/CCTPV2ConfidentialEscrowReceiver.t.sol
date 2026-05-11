// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {CCTPV2ConfidentialEscrowReceiver} from "../../contracts/escrow/receivers/CCTPV2ConfidentialEscrowReceiver.sol";
import {ICCTPV2MessageTransmitter} from "../../contracts/escrow/interfaces/ICCTPV2MessageTransmitter.sol";
import {IConfidentialEscrow} from "../../contracts/escrow/interfaces/IConfidentialEscrow.sol";
import {IConfidentialUSDCWrapper} from "../../contracts/escrow/interfaces/IConfidentialUSDCWrapper.sol";

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

contract MockConfidentialEscrow is IConfidentialEscrow {
    bool public shouldRevert = false;
    uint256 public lastEscrowId;
    uint64 public lastAmount;
    address public lastFrom;

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function fundFrom(uint256 escrowId, uint64 amount, address from) external {
        if (shouldRevert) revert("Escrow fundFrom reverted");
        lastEscrowId = escrowId;
        lastAmount = amount;
        lastFrom = from;
    }
}

contract MockConfidentialUSDCWrapper is IConfidentialUSDCWrapper {
    MockUSDC public usdc;
    bool public shouldRevertWrap = false;
    mapping(address => uint256) public wrappedBalances;

    constructor(address usdc_) {
        usdc = MockUSDC(usdc_);
    }

    function setShouldRevertWrap(bool _shouldRevertWrap) external {
        shouldRevertWrap = _shouldRevertWrap;
    }

    function wrap(uint64 amount) external {
        if (shouldRevertWrap) revert("Wrap reverted");
        usdc.transferFrom(msg.sender, address(this), uint256(amount));
        wrappedBalances[msg.sender] += uint256(amount);
    }

    function unwrap(uint64 amount) external {
        uint256 amt = uint256(amount);
        if (wrappedBalances[msg.sender] < amt) revert("Insufficient wrapped balance");
        wrappedBalances[msg.sender] -= amt;
        usdc.mint(msg.sender, amt);
    }
}

contract CCTPV2ConfidentialEscrowReceiverTest is Test {
    CCTPV2ConfidentialEscrowReceiver public receiver;
    MockCCTPV2MessageTransmitter public cctp;
    MockConfidentialEscrow public escrow;
    MockUSDC public usdc;
    MockConfidentialUSDCWrapper public confUsdc;

    address public owner = address(0xABCD);
    address public nonOwner = address(0xBEEF);
    address public recipient = address(0xCAFE);

    function setUp() public {
        cctp = new MockCCTPV2MessageTransmitter();
        escrow = new MockConfidentialEscrow();
        usdc = new MockUSDC();
        confUsdc = new MockConfidentialUSDCWrapper(address(usdc));
        receiver = new CCTPV2ConfidentialEscrowReceiver(
            address(cctp), address(escrow), address(usdc), address(confUsdc), owner
        );
    }

    ////////////////////////////////////////////////////////////////
    // receiveMessage success path
    ////////////////////////////////////////////////////////////////

    function test_receiveMessage_success() public {
        uint256 amount = 1000e6;
        uint256 escrowId = 42;
        usdc.mint(address(receiver), amount);

        receiver.receiveMessage("", "", escrowId);

        assertEq(escrow.lastEscrowId(), escrowId);
        assertEq(escrow.lastAmount(), uint64(amount));
        assertEq(escrow.lastFrom(), address(receiver));
        assertEq(usdc.balanceOf(address(receiver)), 0);
    }

    function test_receiveMessage_emitsEvent() public {
        uint256 amount = 1000e6;
        uint256 escrowId = 42;
        usdc.mint(address(receiver), amount);

        bytes memory message = "test";
        vm.expectEmit(true, false, false, true);
        emit CCTPV2ConfidentialEscrowReceiver.MessageReceived(keccak256(message), amount, escrowId);

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

    function test_receiveMessage_fundsStuckWhenWrapReverts() public {
        uint256 amount = 1000e6;
        usdc.mint(address(receiver), amount);
        confUsdc.setShouldRevertWrap(true);

        vm.expectRevert("Wrap reverted");
        receiver.receiveMessage("", "", 1);

        // Plain USDC remains stuck in the receiver
        assertEq(usdc.balanceOf(address(receiver)), amount);
    }

    function test_receiveMessage_fundsStuckWhenEscrowReverts() public {
        uint256 amount = 1000e6;
        usdc.mint(address(receiver), amount);
        escrow.setShouldRevert(true);

        vm.expectRevert("Escrow fundFrom reverted");
        receiver.receiveMessage("", "", 1);

        // Transaction reverts atomically, so plain USDC balance rolls back to original amount
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

    ////////////////////////////////////////////////////////////////
    // recoverConfidentialUsdc — owner-only
    ////////////////////////////////////////////////////////////////

    function test_recoverConfidentialUsdc_success() public {
        uint64 amount = 1000e6;
        usdc.mint(address(receiver), uint256(amount));

        // Simulate that the receiver has wrapped USDC
        vm.prank(address(receiver));
        usdc.approve(address(confUsdc), uint256(amount));
        vm.prank(address(receiver));
        confUsdc.wrap(amount);

        // Mint plain USDC to wrapper so unwrap succeeds
        usdc.mint(address(confUsdc), uint256(amount));

        vm.prank(owner);
        receiver.recoverConfidentialUsdc(amount, recipient);

        assertEq(usdc.balanceOf(recipient), uint256(amount));
    }

    function test_recoverConfidentialUsdc_revertsWhenNonOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        receiver.recoverConfidentialUsdc(1, recipient);
    }

    function test_recoverConfidentialUsdc_revertsZeroAmount() public {
        vm.prank(owner);
        vm.expectRevert("Zero amount");
        receiver.recoverConfidentialUsdc(0, recipient);
    }

    function test_recoverConfidentialUsdc_revertsInvalidRecipient() public {
        vm.prank(owner);
        vm.expectRevert("Invalid recipient");
        receiver.recoverConfidentialUsdc(1, address(0));
    }

    function test_recoverConfidentialUsdc_revertsInsufficientBalance() public {
        vm.prank(owner);
        vm.expectRevert("Insufficient wrapped balance");
        receiver.recoverConfidentialUsdc(1, recipient);
    }

    function test_recoverConfidentialUsdc_emitsEvents() public {
        uint64 amount = 1000e6;
        usdc.mint(address(receiver), uint256(amount));

        // Simulate that the receiver has wrapped USDC
        vm.prank(address(receiver));
        usdc.approve(address(confUsdc), uint256(amount));
        vm.prank(address(receiver));
        confUsdc.wrap(amount);

        // Mint plain USDC to wrapper so unwrap succeeds
        usdc.mint(address(confUsdc), uint256(amount));

        vm.prank(owner);
        vm.expectEmit(false, true, false, true);
        emit CCTPV2ConfidentialEscrowReceiver.ConfidentialUsdcRecovered(amount, recipient);
        vm.expectEmit(true, false, true, true);
        emit CCTPV2ConfidentialEscrowReceiver.Recovered(IERC20(address(usdc)), uint256(amount), recipient);
        receiver.recoverConfidentialUsdc(amount, recipient);
    }

    ////////////////////////////////////////////////////////////////
    // end-to-end stuck-funds recovery
    ////////////////////////////////////////////////////////////////

    function test_recover_stuckPlainUsdcAfterWrapRevert() public {
        uint256 amount = 1000e6;
        uint256 escrowId = 7;
        usdc.mint(address(receiver), amount);
        confUsdc.setShouldRevertWrap(true);

        vm.expectRevert("Wrap reverted");
        receiver.receiveMessage("", "", escrowId);

        assertEq(usdc.balanceOf(address(receiver)), amount);

        vm.prank(owner);
        receiver.recover(IERC20(address(usdc)), amount, recipient);

        assertEq(usdc.balanceOf(recipient), amount);
    }

    function test_recoverConfidentialUsdc_afterEscrowRevert() public {
        uint64 amount = 1000e6;
        usdc.mint(address(receiver), uint256(amount));

        // Simulate stuck confidential USDC by wrapping directly
        vm.prank(address(receiver));
        usdc.approve(address(confUsdc), uint256(amount));
        vm.prank(address(receiver));
        confUsdc.wrap(amount);

        // Receiver has 0 plain USDC, wrapped balance is tracked in mock
        assertEq(usdc.balanceOf(address(receiver)), 0);

        // Mint plain USDC to wrapper so unwrap succeeds
        usdc.mint(address(confUsdc), uint256(amount));

        vm.prank(owner);
        receiver.recoverConfidentialUsdc(amount, recipient);

        assertEq(usdc.balanceOf(recipient), uint256(amount));
    }
}
