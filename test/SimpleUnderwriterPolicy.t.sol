// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {SimpleUnderwriterPolicy} from "../contracts/policies/SimpleUnderwriterPolicy.sol";
import {IUnderwriterPolicy} from "../contracts/interfaces/IUnderwriterPolicy.sol";

contract SimpleUnderwriterPolicyTest is Test {
    SimpleUnderwriterPolicy public policy;

    uint256 constant COVERAGE_ID = 1;
    uint256 constant ESCROW_ID = 100;
    uint64 constant BASE_RISK_SCORE = 500; // 5%

    function setUp() public {
        policy = new SimpleUnderwriterPolicy();
    }

    function test_OnPolicySet() public {
        bytes memory data = abi.encode(BASE_RISK_SCORE);

        vm.expectEmit(true, false, false, true);
        emit SimpleUnderwriterPolicy.PolicySet(COVERAGE_ID, BASE_RISK_SCORE);

        policy.onPolicySet(COVERAGE_ID, data);

        (uint64 storedScore, bool configured) = policy.policies(COVERAGE_ID);
        assertEq(storedScore, BASE_RISK_SCORE);
        assertTrue(configured);
    }

    function test_OnPolicySet_RevertsIfAlreadySet() public {
        bytes memory data = abi.encode(BASE_RISK_SCORE);
        policy.onPolicySet(COVERAGE_ID, data);

        vm.expectRevert(SimpleUnderwriterPolicy.PolicyAlreadySet.selector);
        policy.onPolicySet(COVERAGE_ID, data);
    }

    function test_OnPolicySet_RevertsIfScoreTooHigh() public {
        uint64 invalidScore = 10001;
        bytes memory data = abi.encode(invalidScore);

        vm.expectRevert("Risk score must be <= 10000 bps");
        policy.onPolicySet(COVERAGE_ID, data);
    }

    function test_EvaluateRisk() public {
        bytes memory policyData = abi.encode(BASE_RISK_SCORE);
        policy.onPolicySet(COVERAGE_ID, policyData);

        bytes memory riskProof = "";
        policy.evaluateRisk(ESCROW_ID, riskProof);
    }

    function test_EvaluateRisk_RevertsIfNotConfigured() public {
        bytes memory riskProof = "";

        vm.expectRevert("Policy not configured");
        policy.evaluateRisk(ESCROW_ID, riskProof);
    }

    function test_Judge_ValidDispute() public {
        bytes memory policyData = abi.encode(BASE_RISK_SCORE);
        policy.onPolicySet(COVERAGE_ID, policyData);

        bytes memory disputeProof = abi.encode(true, block.timestamp);
        policy.judge(COVERAGE_ID, disputeProof);
    }

    function test_Judge_InvalidDispute() public {
        bytes memory policyData = abi.encode(BASE_RISK_SCORE);
        policy.onPolicySet(COVERAGE_ID, policyData);

        bytes memory disputeProof = abi.encode(false, block.timestamp);
        policy.judge(COVERAGE_ID, disputeProof);
    }

    function test_Judge_OldDispute() public {
        bytes memory policyData = abi.encode(BASE_RISK_SCORE);
        policy.onPolicySet(COVERAGE_ID, policyData);

        uint256 oldTimestamp = block.timestamp - 31 days;
        bytes memory disputeProof = abi.encode(true, oldTimestamp);
        policy.judge(COVERAGE_ID, disputeProof);
    }

    function test_Judge_RevertsIfNotConfigured() public {
        bytes memory disputeProof = abi.encode(true, block.timestamp);

        vm.expectRevert("Policy not configured");
        policy.judge(COVERAGE_ID, disputeProof);
    }

    function test_SupportsInterface() public view {
        bytes4 policyInterface = type(IUnderwriterPolicy).interfaceId;
        assertTrue(policy.supportsInterface(policyInterface));
    }

    function testFuzz_OnPolicySet(uint64 riskScore) public {
        vm.assume(riskScore <= 10000);

        bytes memory data = abi.encode(riskScore);
        policy.onPolicySet(COVERAGE_ID, data);

        (uint64 storedScore, bool configured) = policy.policies(COVERAGE_ID);
        assertEq(storedScore, riskScore);
        assertTrue(configured);
    }
}
