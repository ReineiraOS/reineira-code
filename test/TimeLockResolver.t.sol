// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {TimeLockResolver} from "../contracts/resolvers/TimelockResolver.sol";
import {IConditionResolver} from "../contracts/interfaces/IConditionResolver.sol";

contract TimeLockResolverTest is Test {
    TimeLockResolver public resolver;

    uint256 constant ESCROW_ID = 1;
    uint256 deadline;

    function setUp() public {
        resolver = new TimeLockResolver();
        deadline = block.timestamp + 1 days;
    }

    function test_OnConditionSet() public {
        bytes memory data = abi.encode(deadline);

        vm.expectEmit(true, false, false, true);
        emit TimeLockResolver.ConditionSet(ESCROW_ID, deadline);

        resolver.onConditionSet(ESCROW_ID, data);

        (uint256 storedDeadline) = resolver.configs(ESCROW_ID);
        assertEq(storedDeadline, deadline);
    }

    function test_OnConditionSet_RevertsIfPastDeadline() public {
        uint256 pastDeadline = block.timestamp - 1;
        bytes memory data = abi.encode(pastDeadline);

        vm.expectRevert(TimeLockResolver.InvalidDeadline.selector);
        resolver.onConditionSet(ESCROW_ID, data);
    }

    function test_OnConditionSet_RevertsIfAlreadySet() public {
        bytes memory data = abi.encode(deadline);
        resolver.onConditionSet(ESCROW_ID, data);

        vm.expectRevert(TimeLockResolver.ConditionAlreadySet.selector);
        resolver.onConditionSet(ESCROW_ID, data);
    }

    function test_IsConditionMet_ReturnsFalseBeforeDeadline() public {
        bytes memory data = abi.encode(deadline);
        resolver.onConditionSet(ESCROW_ID, data);

        assertFalse(resolver.isConditionMet(ESCROW_ID));
    }

    function test_IsConditionMet_ReturnsTrueAfterDeadline() public {
        bytes memory data = abi.encode(deadline);
        resolver.onConditionSet(ESCROW_ID, data);

        vm.warp(deadline);
        assertTrue(resolver.isConditionMet(ESCROW_ID));
    }

    function test_IsConditionMet_ReturnsTrueAfterDeadlinePassed() public {
        bytes memory data = abi.encode(deadline);
        resolver.onConditionSet(ESCROW_ID, data);

        vm.warp(deadline + 1 hours);
        assertTrue(resolver.isConditionMet(ESCROW_ID));
    }

    function test_SupportsInterface() public view {
        bytes4 resolverInterface = type(IConditionResolver).interfaceId;
        assertTrue(resolver.supportsInterface(resolverInterface));
    }

    function testFuzz_OnConditionSet(uint256 futureDeadline) public {
        vm.assume(futureDeadline > block.timestamp);
        vm.assume(futureDeadline < type(uint256).max);

        bytes memory data = abi.encode(futureDeadline);
        resolver.onConditionSet(ESCROW_ID, data);

        (uint256 storedDeadline) = resolver.configs(ESCROW_ID);
        assertEq(storedDeadline, futureDeadline);
    }
}
