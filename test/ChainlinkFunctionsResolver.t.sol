// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ChainlinkFunctionsResolver} from "../contracts/resolvers/ChainlinkFunctionsResolver.sol";

contract MockFunctionsRouter {
    mapping(bytes32 => bool) public pendingRequests;
    bytes32 public lastRequestId;

    function sendRequest(uint64, bytes memory, uint16, uint32, bytes32) external returns (bytes32) {
        bytes32 requestId = keccak256(abi.encodePacked(block.timestamp, msg.sender));
        pendingRequests[requestId] = true;
        lastRequestId = requestId;
        return requestId;
    }

    function fulfill(address consumer, bytes32 requestId, bytes memory response, bytes memory err) external {
        ChainlinkFunctionsResolver(consumer).handleOracleFulfillment(requestId, response, err);
        pendingRequests[requestId] = false;
    }
}

contract ChainlinkFunctionsResolverTest is Test {
    ChainlinkFunctionsResolver public resolver;
    MockFunctionsRouter public mockRouter;

    uint256 constant ESCROW_ID = 1;
    uint64 constant SUBSCRIPTION_ID = 123;
    uint32 constant GAS_LIMIT = 300000;
    bytes32 constant DON_ID = 0x66756e2d617262697472756d2d7365706f6c69612d3100000000000000000000;

    string constant SOURCE = "return Functions.encodeUint256(42);";
    bytes constant EXPECTED_RESULT = abi.encode(uint256(42));

    function setUp() public {
        mockRouter = new MockFunctionsRouter();
        resolver = new ChainlinkFunctionsResolver(address(mockRouter));
    }

    function test_ConfigureCondition() public {
        string[] memory args = new string[](0);
        bytes memory encryptedSecretsUrls = "";

        bytes memory data =
            abi.encode(SOURCE, args, encryptedSecretsUrls, SUBSCRIPTION_ID, GAS_LIMIT, DON_ID, EXPECTED_RESULT);

        vm.expectEmit(true, false, false, true);
        emit ChainlinkFunctionsResolver.ConditionConfigured(
            ESCROW_ID, SUBSCRIPTION_ID, DON_ID, GAS_LIMIT, EXPECTED_RESULT
        );

        resolver.onConditionSet(ESCROW_ID, data);

        ChainlinkFunctionsResolver.Config memory config = resolver.getConfig(ESCROW_ID);
        assertEq(config.subscriptionId, SUBSCRIPTION_ID);
        assertEq(config.gasLimit, GAS_LIMIT);
        assertEq(config.donId, DON_ID);
        assertEq(config.expectedResult, EXPECTED_RESULT);
        assertTrue(config.configured);
        assertFalse(config.fulfilled);
    }

    function test_RevertWhen_EmptySource() public {
        string[] memory args = new string[](0);
        bytes memory data = abi.encode("", args, "", SUBSCRIPTION_ID, GAS_LIMIT, DON_ID, EXPECTED_RESULT);

        vm.expectRevert(ChainlinkFunctionsResolver.EmptySource.selector);
        resolver.onConditionSet(ESCROW_ID, data);
    }

    function test_RevertWhen_InvalidSubscriptionId() public {
        string[] memory args = new string[](0);
        bytes memory data = abi.encode(SOURCE, args, "", uint64(0), GAS_LIMIT, DON_ID, EXPECTED_RESULT);

        vm.expectRevert(ChainlinkFunctionsResolver.InvalidSubscriptionId.selector);
        resolver.onConditionSet(ESCROW_ID, data);
    }

    function test_RevertWhen_ConditionAlreadySet() public {
        string[] memory args = new string[](0);
        bytes memory data = abi.encode(SOURCE, args, "", SUBSCRIPTION_ID, GAS_LIMIT, DON_ID, EXPECTED_RESULT);

        resolver.onConditionSet(ESCROW_ID, data);

        vm.expectRevert(ChainlinkFunctionsResolver.ConditionAlreadySet.selector);
        resolver.onConditionSet(ESCROW_ID, data);
    }

    function test_ExecuteRequest() public {
        string[] memory args = new string[](0);
        bytes memory data = abi.encode(SOURCE, args, "", SUBSCRIPTION_ID, GAS_LIMIT, DON_ID, EXPECTED_RESULT);
        resolver.onConditionSet(ESCROW_ID, data);

        vm.expectEmit(true, false, false, false);
        emit ChainlinkFunctionsResolver.RequestSent(ESCROW_ID, bytes32(0));

        bytes32 requestId = resolver.executeRequest(ESCROW_ID);

        assertTrue(requestId != bytes32(0));
        assertEq(resolver.getLastRequestId(ESCROW_ID), requestId);
    }

    function test_RevertWhen_ExecuteRequestNotConfigured() public {
        vm.expectRevert(ChainlinkFunctionsResolver.ConditionNotConfigured.selector);
        resolver.executeRequest(ESCROW_ID);
    }

    function test_FulfillRequest_Success() public {
        string[] memory args = new string[](0);
        bytes memory data = abi.encode(SOURCE, args, "", SUBSCRIPTION_ID, GAS_LIMIT, DON_ID, EXPECTED_RESULT);
        resolver.onConditionSet(ESCROW_ID, data);

        bytes32 requestId = resolver.executeRequest(ESCROW_ID);

        vm.expectEmit(true, true, false, true);
        emit ChainlinkFunctionsResolver.ConditionFulfilled(ESCROW_ID, EXPECTED_RESULT);

        mockRouter.fulfill(address(resolver), requestId, EXPECTED_RESULT, "");

        assertTrue(resolver.isConditionMet(ESCROW_ID));
    }

    function test_FulfillRequest_Mismatch() public {
        string[] memory args = new string[](0);
        bytes memory data = abi.encode(SOURCE, args, "", SUBSCRIPTION_ID, GAS_LIMIT, DON_ID, EXPECTED_RESULT);
        resolver.onConditionSet(ESCROW_ID, data);

        bytes32 requestId = resolver.executeRequest(ESCROW_ID);

        bytes memory wrongResult = abi.encode(uint256(99));
        mockRouter.fulfill(address(resolver), requestId, wrongResult, "");

        assertFalse(resolver.isConditionMet(ESCROW_ID));
    }

    function test_FulfillRequest_WithError() public {
        string[] memory args = new string[](0);
        bytes memory data = abi.encode(SOURCE, args, "", SUBSCRIPTION_ID, GAS_LIMIT, DON_ID, EXPECTED_RESULT);
        resolver.onConditionSet(ESCROW_ID, data);

        bytes32 requestId = resolver.executeRequest(ESCROW_ID);

        mockRouter.fulfill(address(resolver), requestId, "", "Error occurred");

        assertFalse(resolver.isConditionMet(ESCROW_ID));
    }

    function test_GetSource() public {
        string[] memory args = new string[](0);
        bytes memory data = abi.encode(SOURCE, args, "", SUBSCRIPTION_ID, GAS_LIMIT, DON_ID, EXPECTED_RESULT);
        resolver.onConditionSet(ESCROW_ID, data);

        assertEq(resolver.getSource(ESCROW_ID), SOURCE);
    }

    function test_DefaultGasLimit() public {
        string[] memory args = new string[](0);
        bytes memory data = abi.encode(SOURCE, args, "", SUBSCRIPTION_ID, uint32(0), DON_ID, EXPECTED_RESULT);
        resolver.onConditionSet(ESCROW_ID, data);

        ChainlinkFunctionsResolver.Config memory config = resolver.getConfig(ESCROW_ID);
        assertEq(config.gasLimit, 300000);
    }

    function test_SupportsInterface() public {
        // ChainlinkFunctionsResolver is a contract, not an interface
        // Test with IConditionResolver interface instead
        bytes4 interfaceId = 0x01ffc9a7; // ERC165 interface ID
        assertTrue(resolver.supportsInterface(interfaceId));
    }
}
