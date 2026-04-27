// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MoneroTxResolver} from "../contracts/resolvers/MoneroTxResolver.sol";
import {IConditionResolver} from "../contracts/interfaces/IConditionResolver.sol";

/// @notice Mock Reclaim verifier for testing
contract MockReclaimVerifier {
    bool public shouldRevert;
    
    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }
    
    function verifyProof(
        string memory,
        string memory,
        string memory,
        bytes32,
        address,
        uint32,
        uint32,
        bytes[] memory
    ) external view {
        if (shouldRevert) {
            revert("Mock verification failed");
        }
    }
}

contract MoneroTxResolverTest is Test {
    MoneroTxResolver public resolver;
    MockReclaimVerifier public mockReclaim;
    
    uint256 constant ESCROW_ID = 1;
    string constant TX_HASH = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2";
    string constant RECIPIENT = "4AdUndXHHZ6cfufTMvppY6JwXNouMBzSkbLYfpAV5Usx3skxNgYeYTRj5UzqtReoS44qo9mtmXCqY45DJ852K5Jv2684Rge";
    uint256 constant MIN_AMOUNT = 1000000000000; // 1 XMR in piconeros
    uint256 constant MIN_CONFIRMATIONS = 10;
    
    bytes32 validIdentifier;
    
    function setUp() public {
        resolver = new MoneroTxResolver();
        mockReclaim = new MockReclaimVerifier();
        
        validIdentifier = keccak256("unique_proof_id");
    }
    
    function test_OnConditionSet() public {
        bytes memory data = abi.encode(
            address(mockReclaim),
            TX_HASH,
            RECIPIENT,
            MIN_AMOUNT,
            MIN_CONFIRMATIONS
        );
        
        vm.expectEmit(true, false, false, true);
        emit MoneroTxResolver.ConditionSet(
            ESCROW_ID,
            address(mockReclaim),
            TX_HASH,
            RECIPIENT,
            MIN_AMOUNT,
            MIN_CONFIRMATIONS
        );
        
        resolver.onConditionSet(ESCROW_ID, data);
        
        (
            address storedReclaim,
            string memory storedTxHash,
            string memory storedRecipient,
            uint256 storedMinAmount,
            uint256 storedMinConfirmations,
            bool fulfilled
        ) = resolver.configs(ESCROW_ID);
        
        assertEq(storedReclaim, address(mockReclaim));
        assertEq(storedTxHash, TX_HASH);
        assertEq(storedRecipient, RECIPIENT);
        assertEq(storedMinAmount, MIN_AMOUNT);
        assertEq(storedMinConfirmations, MIN_CONFIRMATIONS);
        assertFalse(fulfilled);
    }
    
    function test_RevertIf_ConditionAlreadySet() public {
        bytes memory data = abi.encode(
            address(mockReclaim),
            TX_HASH,
            RECIPIENT,
            MIN_AMOUNT,
            MIN_CONFIRMATIONS
        );
        
        resolver.onConditionSet(ESCROW_ID, data);
        
        vm.expectRevert(MoneroTxResolver.ConditionAlreadySet.selector);
        resolver.onConditionSet(ESCROW_ID, data);
    }
    
    function test_RevertIf_InvalidReclaimAddress() public {
        bytes memory data = abi.encode(
            address(0),
            TX_HASH,
            RECIPIENT,
            MIN_AMOUNT,
            MIN_CONFIRMATIONS
        );
        
        vm.expectRevert(MoneroTxResolver.InvalidReclaimAddress.selector);
        resolver.onConditionSet(ESCROW_ID, data);
    }
    
    function test_RevertIf_EmptyTxHash() public {
        bytes memory data = abi.encode(
            address(mockReclaim),
            "",
            RECIPIENT,
            MIN_AMOUNT,
            MIN_CONFIRMATIONS
        );
        
        vm.expectRevert(MoneroTxResolver.EmptyTxHash.selector);
        resolver.onConditionSet(ESCROW_ID, data);
    }
    
    function test_SubmitProof_Success() public {
        // Setup condition
        bytes memory configData = abi.encode(
            address(mockReclaim),
            TX_HASH,
            "",  // No recipient check for this test
            0,   // No amount check
            0    // No confirmations check
        );
        resolver.onConditionSet(ESCROW_ID, configData);
        
        // Create mock proof with tx_hash in context
        // Format matches actual Reclaim proof context
        string memory context = string(abi.encodePacked(
            '{"tx_hash":"',
            TX_HASH,
            '"}'
        ));
        
        bytes memory proofData = abi.encode(
            "http",           // provider
            "",               // parameters
            context,          // context with tx_hash
            validIdentifier,  // identifier
            address(this),    // owner
            uint32(block.timestamp), // timestampS
            uint32(1),        // epoch
            new bytes[](0)    // signatures
        );
        
        vm.expectEmit(true, true, false, true);
        emit MoneroTxResolver.TransactionVerified(
            ESCROW_ID,
            validIdentifier,
            TX_HASH,
            0,
            0
        );
        
        resolver.submitProof(ESCROW_ID, proofData);
        
        assertTrue(resolver.isConditionMet(ESCROW_ID));
        assertTrue(resolver.usedProofIdentifiers(validIdentifier));
    }
    
    function test_RevertIf_AlreadyFulfilled() public {
        // Setup and fulfill
        bytes memory configData = abi.encode(
            address(mockReclaim),
            TX_HASH,
            "",
            0,
            0
        );
        resolver.onConditionSet(ESCROW_ID, configData);
        
        string memory context = string(abi.encodePacked(
            '{"tx_hash":"',
            TX_HASH,
            '"}'
        ));
        
        bytes memory proofData = abi.encode(
            "http",
            "",
            context,
            validIdentifier,
            address(this),
            uint32(block.timestamp),
            uint32(1),
            new bytes[](0)
        );
        
        resolver.submitProof(ESCROW_ID, proofData);
        
        // Try to submit again
        vm.expectRevert(MoneroTxResolver.AlreadyFulfilled.selector);
        resolver.submitProof(ESCROW_ID, proofData);
    }
    
    function test_RevertIf_ProofAlreadyUsed() public {
        // Setup two escrows
        bytes memory configData = abi.encode(
            address(mockReclaim),
            TX_HASH,
            "",
            0,
            0
        );
        resolver.onConditionSet(ESCROW_ID, configData);
        resolver.onConditionSet(ESCROW_ID + 1, configData);
        
        string memory context = string(abi.encodePacked(
            '{"tx_hash":"',
            TX_HASH,
            '"}'
        ));
        
        bytes memory proofData = abi.encode(
            "http",
            "",
            context,
            validIdentifier,
            address(this),
            uint32(block.timestamp),
            uint32(1),
            new bytes[](0)
        );
        
        // Use proof for first escrow
        resolver.submitProof(ESCROW_ID, proofData);
        
        // Try to use same proof for second escrow
        vm.expectRevert(MoneroTxResolver.ProofAlreadyUsed.selector);
        resolver.submitProof(ESCROW_ID + 1, proofData);
    }
    
    function test_RevertIf_InvalidProof() public {
        bytes memory configData = abi.encode(
            address(mockReclaim),
            TX_HASH,
            "",
            0,
            0
        );
        resolver.onConditionSet(ESCROW_ID, configData);
        
        // Set mock to revert
        mockReclaim.setShouldRevert(true);
        
        string memory context = string(abi.encodePacked(
            '{"tx_hash":"',
            TX_HASH,
            '"}'
        ));
        
        bytes memory proofData = abi.encode(
            "http",
            "",
            context,
            validIdentifier,
            address(this),
            uint32(block.timestamp),
            uint32(1),
            new bytes[](0)
        );
        
        vm.expectRevert(MoneroTxResolver.InvalidProof.selector);
        resolver.submitProof(ESCROW_ID, proofData);
    }
    
    function test_RevertIf_TxHashMismatch() public {
        bytes memory configData = abi.encode(
            address(mockReclaim),
            TX_HASH,
            "",
            0,
            0
        );
        resolver.onConditionSet(ESCROW_ID, configData);
        
        // Wrong tx hash in context
        string memory wrongHash = "0000000000000000000000000000000000000000000000000000000000000000";
        string memory context = string(abi.encodePacked(
            '{"tx_hash":"',
            wrongHash,
            '"}'
        ));
        
        bytes memory proofData = abi.encode(
            "http",
            "",
            context,
            validIdentifier,
            address(this),
            uint32(block.timestamp),
            uint32(1),
            new bytes[](0)
        );
        
        vm.expectRevert(MoneroTxResolver.TxHashMismatch.selector);
        resolver.submitProof(ESCROW_ID, proofData);
    }
    
    function test_SupportsInterface() public {
        assertTrue(resolver.supportsInterface(type(IConditionResolver).interfaceId));
    }
    
    function test_IsConditionMet_InitiallyFalse() public {
        assertFalse(resolver.isConditionMet(ESCROW_ID));
    }
}
