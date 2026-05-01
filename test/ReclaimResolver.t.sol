// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ReclaimResolver} from "../contracts/resolvers/ReclaimResolver.sol";
import {IConditionResolver} from "../contracts/interfaces/IConditionResolver.sol";

/// @notice Mock Reclaim verifier contract for testing
/// @dev Simulates the Reclaim Protocol's verifyProof function
contract MockReclaimVerifier {
    bool public shouldRevert;
    mapping(bytes32 => bool) public validIdentifiers;

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function setValidIdentifier(bytes32 identifier, bool valid) external {
        validIdentifiers[identifier] = valid;
    }

    /// @dev Mock verifyProof that matches Reclaim's signature
    /// @dev Accepts ClaimInfo and SignedClaim structs
    function verifyProof(
        string memory, // provider
        string memory, // parameters
        string memory, // context
        bytes32 identifier,
        address, // owner
        uint32, // timestampS
        uint32, // epoch
        bytes[] memory // signatures
    ) external view {
        if (shouldRevert) {
            revert("Mock verification failed");
        }
        require(validIdentifiers[identifier], "Invalid identifier");
    }
}

contract ReclaimResolverTest is Test {
    ReclaimResolver public resolver;
    MockReclaimVerifier public mockReclaim;

    uint256 constant ESCROW_ID = 1;
    string constant PROVIDER = "http";
    string constant EXPECTED_ADDRESS = "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb";
    string constant EXPECTED_MESSAGE = "payment_received";

    bytes32 validIdentifier;
    address proofOwner;
    uint32 timestamp;
    uint32 epoch;

    function setUp() public {
        resolver = new ReclaimResolver();
        mockReclaim = new MockReclaimVerifier();

        validIdentifier = keccak256("unique_proof_id");
        proofOwner = address(0x123);
        timestamp = uint32(block.timestamp);
        epoch = 1;

        mockReclaim.setValidIdentifier(validIdentifier, true);
    }

    function test_OnConditionSet() public {
        bytes memory data = abi.encode(address(mockReclaim), PROVIDER, EXPECTED_ADDRESS, EXPECTED_MESSAGE);

        vm.expectEmit(true, false, false, true);
        emit ReclaimResolver.ConditionSet(ESCROW_ID, address(mockReclaim), PROVIDER, EXPECTED_ADDRESS, EXPECTED_MESSAGE);

        resolver.onConditionSet(ESCROW_ID, data);

        (
            address storedReclaim,
            string memory storedProvider,
            string memory storedAddress,
            string memory storedMessage,
            bool fulfilled
        ) = resolver.configs(ESCROW_ID);

        assertEq(storedReclaim, address(mockReclaim));
        assertEq(storedProvider, PROVIDER);
        assertEq(storedAddress, EXPECTED_ADDRESS);
        assertEq(storedMessage, EXPECTED_MESSAGE);
        assertFalse(fulfilled);
    }

    function test_OnConditionSet_RevertsIfZeroAddress() public {
        bytes memory data = abi.encode(address(0), PROVIDER, EXPECTED_ADDRESS, EXPECTED_MESSAGE);

        vm.expectRevert(ReclaimResolver.InvalidReclaimAddress.selector);
        resolver.onConditionSet(ESCROW_ID, data);
    }

    function test_OnConditionSet_RevertsIfEmptyProvider() public {
        bytes memory data = abi.encode(address(mockReclaim), "", EXPECTED_ADDRESS, EXPECTED_MESSAGE);

        vm.expectRevert(ReclaimResolver.EmptyProvider.selector);
        resolver.onConditionSet(ESCROW_ID, data);
    }

    function test_OnConditionSet_RevertsIfAlreadySet() public {
        bytes memory data = abi.encode(address(mockReclaim), PROVIDER, EXPECTED_ADDRESS, EXPECTED_MESSAGE);
        resolver.onConditionSet(ESCROW_ID, data);

        vm.expectRevert(ReclaimResolver.ConditionAlreadySet.selector);
        resolver.onConditionSet(ESCROW_ID, data);
    }

    function test_OnConditionSet_AllowsEmptyContextFields() public {
        bytes memory data = abi.encode(
            address(mockReclaim),
            PROVIDER,
            "", // empty context address
            "" // empty context message
        );

        resolver.onConditionSet(ESCROW_ID, data);

        (
            address storedReclaim,
            string memory storedProvider,
            string memory storedAddress,
            string memory storedMessage,
            bool fulfilled
        ) = resolver.configs(ESCROW_ID);

        assertEq(storedReclaim, address(mockReclaim));
        assertEq(storedProvider, PROVIDER);
        assertEq(storedAddress, "");
        assertEq(storedMessage, "");
        assertFalse(fulfilled);
    }

    function test_SubmitProof_Success() public {
        bytes memory configData = abi.encode(address(mockReclaim), PROVIDER, EXPECTED_ADDRESS, EXPECTED_MESSAGE);
        resolver.onConditionSet(ESCROW_ID, configData);

        string memory context = string(
            abi.encodePacked('{"contextAddress":"', EXPECTED_ADDRESS, '","contextMessage":"', EXPECTED_MESSAGE, '"}')
        );

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = hex"1234";

        bytes memory proofData =
            abi.encode(PROVIDER, "parameters", context, validIdentifier, proofOwner, timestamp, epoch, signatures);

        vm.expectEmit(true, false, false, true);
        emit ReclaimResolver.ProofSubmitted(ESCROW_ID, validIdentifier);

        resolver.submitProof(ESCROW_ID, proofData);

        assertTrue(resolver.isConditionMet(ESCROW_ID));
        assertTrue(resolver.usedProofIdentifiers(validIdentifier));
    }

    function test_SubmitProof_SuccessWithoutContextValidation() public {
        bytes memory configData = abi.encode(
            address(mockReclaim),
            PROVIDER,
            "", // no context address check
            "" // no context message check
        );
        resolver.onConditionSet(ESCROW_ID, configData);

        string memory context = '{"someField":"someValue"}';

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = hex"1234";

        bytes memory proofData =
            abi.encode(PROVIDER, "parameters", context, validIdentifier, proofOwner, timestamp, epoch, signatures);

        resolver.submitProof(ESCROW_ID, proofData);

        assertTrue(resolver.isConditionMet(ESCROW_ID));
    }

    function test_SubmitProof_RevertsIfAlreadyFulfilled() public {
        bytes memory configData = abi.encode(address(mockReclaim), PROVIDER, "", "");
        resolver.onConditionSet(ESCROW_ID, configData);

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = hex"1234";

        bytes memory proofData =
            abi.encode(PROVIDER, "parameters", "{}", validIdentifier, proofOwner, timestamp, epoch, signatures);

        resolver.submitProof(ESCROW_ID, proofData);

        vm.expectRevert(ReclaimResolver.AlreadyFulfilled.selector);
        resolver.submitProof(ESCROW_ID, proofData);
    }

    function test_SubmitProof_RevertsIfProofReused() public {
        bytes memory configData = abi.encode(address(mockReclaim), PROVIDER, "", "");
        resolver.onConditionSet(ESCROW_ID, configData);

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = hex"1234";

        bytes memory proofData =
            abi.encode(PROVIDER, "parameters", "{}", validIdentifier, proofOwner, timestamp, epoch, signatures);

        resolver.submitProof(ESCROW_ID, proofData);

        uint256 escrowId2 = 2;
        resolver.onConditionSet(escrowId2, configData);

        vm.expectRevert(ReclaimResolver.ProofAlreadyUsed.selector);
        resolver.submitProof(escrowId2, proofData);
    }

    function test_SubmitProof_RevertsIfProviderMismatch() public {
        bytes memory configData = abi.encode(address(mockReclaim), PROVIDER, "", "");
        resolver.onConditionSet(ESCROW_ID, configData);

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = hex"1234";

        bytes memory proofData =
            abi.encode("wrong_provider", "parameters", "{}", validIdentifier, proofOwner, timestamp, epoch, signatures);

        vm.expectRevert(ReclaimResolver.ProviderMismatch.selector);
        resolver.submitProof(ESCROW_ID, proofData);
    }

    function test_SubmitProof_RevertsIfContextAddressMismatch() public {
        bytes memory configData = abi.encode(address(mockReclaim), PROVIDER, EXPECTED_ADDRESS, "");
        resolver.onConditionSet(ESCROW_ID, configData);

        string memory wrongContext = '{"contextAddress":"0xWrongAddress"}';

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = hex"1234";

        bytes memory proofData =
            abi.encode(PROVIDER, "parameters", wrongContext, validIdentifier, proofOwner, timestamp, epoch, signatures);

        vm.expectRevert(ReclaimResolver.ContextAddressMismatch.selector);
        resolver.submitProof(ESCROW_ID, proofData);
    }

    function test_SubmitProof_RevertsIfContextMessageMismatch() public {
        bytes memory configData = abi.encode(address(mockReclaim), PROVIDER, "", EXPECTED_MESSAGE);
        resolver.onConditionSet(ESCROW_ID, configData);

        string memory wrongContext = '{"contextMessage":"wrong_message"}';

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = hex"1234";

        bytes memory proofData =
            abi.encode(PROVIDER, "parameters", wrongContext, validIdentifier, proofOwner, timestamp, epoch, signatures);

        vm.expectRevert(ReclaimResolver.ContextMessageMismatch.selector);
        resolver.submitProof(ESCROW_ID, proofData);
    }

    function test_SubmitProof_RevertsIfReclaimVerificationFails() public {
        bytes memory configData = abi.encode(address(mockReclaim), PROVIDER, "", "");
        resolver.onConditionSet(ESCROW_ID, configData);

        mockReclaim.setShouldRevert(true);

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = hex"1234";

        bytes memory proofData =
            abi.encode(PROVIDER, "parameters", "{}", validIdentifier, proofOwner, timestamp, epoch, signatures);

        vm.expectRevert(ReclaimResolver.InvalidProof.selector);
        resolver.submitProof(ESCROW_ID, proofData);
    }

    function test_IsConditionMet_ReturnsFalseBeforeProof() public {
        bytes memory configData = abi.encode(address(mockReclaim), PROVIDER, "", "");
        resolver.onConditionSet(ESCROW_ID, configData);

        assertFalse(resolver.isConditionMet(ESCROW_ID));
    }

    function test_IsConditionMet_ReturnsTrueAfterProof() public {
        bytes memory configData = abi.encode(address(mockReclaim), PROVIDER, "", "");
        resolver.onConditionSet(ESCROW_ID, configData);

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = hex"1234";

        bytes memory proofData =
            abi.encode(PROVIDER, "parameters", "{}", validIdentifier, proofOwner, timestamp, epoch, signatures);

        resolver.submitProof(ESCROW_ID, proofData);

        assertTrue(resolver.isConditionMet(ESCROW_ID));
    }

    function test_SupportsInterface() public view {
        bytes4 resolverInterface = type(IConditionResolver).interfaceId;
        assertTrue(resolver.supportsInterface(resolverInterface));
    }

    function testFuzz_OnConditionSet(address fuzzReclaim, string memory fuzzProvider) public {
        vm.assume(fuzzReclaim != address(0));
        vm.assume(bytes(fuzzProvider).length > 0);
        vm.assume(bytes(fuzzProvider).length < 1000);

        bytes memory data = abi.encode(fuzzReclaim, fuzzProvider, "", "");
        resolver.onConditionSet(ESCROW_ID, data);

        (address storedReclaim, string memory storedProvider,,,) = resolver.configs(ESCROW_ID);
        assertEq(storedReclaim, fuzzReclaim);
        assertEq(storedProvider, fuzzProvider);
    }
}
