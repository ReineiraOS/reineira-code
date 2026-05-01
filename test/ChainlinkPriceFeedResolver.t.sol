// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ChainlinkPriceFeedResolver} from "../contracts/resolvers/ChainlinkPriceFeedResolver.sol";
import {IOracleConditionResolver} from "../contracts/interfaces/IOracleConditionResolver.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract MockAggregator is AggregatorV3Interface {
    int256 private _answer;
    uint256 private _updatedAt;
    uint8 private _decimals;

    constructor(int256 initialAnswer, uint8 decimals_) {
        _answer = initialAnswer;
        _updatedAt = block.timestamp;
        _decimals = decimals_;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function description() external pure returns (string memory) {
        return "Mock Aggregator";
    }

    function version() external pure returns (uint256) {
        return 1;
    }

    function getRoundData(uint80)
        external
        pure
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        revert("Not implemented");
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (1, _answer, block.timestamp, _updatedAt, 1);
    }

    function setAnswer(int256 newAnswer) external {
        _answer = newAnswer;
        _updatedAt = block.timestamp;
    }

    function setUpdatedAt(uint256 timestamp) external {
        _updatedAt = timestamp;
    }
}

contract ChainlinkPriceFeedResolverTest is Test {
    ChainlinkPriceFeedResolver public resolver;
    MockAggregator public mockFeed;

    uint256 constant ESCROW_ID = 1;
    int256 constant INITIAL_PRICE = 2000 * 10 ** 8;
    uint8 constant DECIMALS = 8;

    function setUp() public {
        resolver = new ChainlinkPriceFeedResolver();
        mockFeed = new MockAggregator(INITIAL_PRICE, DECIMALS);
    }

    function test_ConfigureCondition() public {
        int256 threshold = 1500 * 10 ** 8;
        uint8 op = uint8(IOracleConditionResolver.ComparisonOp.GreaterThan);
        uint256 maxStaleness = 3600;

        bytes memory data = abi.encode(address(mockFeed), threshold, op, maxStaleness);

        vm.expectEmit(true, true, false, true);
        emit ChainlinkPriceFeedResolver.PriceFeedConfigured(ESCROW_ID, address(mockFeed));

        resolver.onConditionSet(ESCROW_ID, data);

        assertEq(resolver.getFeedAddress(ESCROW_ID), address(mockFeed));

        (int256 storedThreshold, IOracleConditionResolver.ComparisonOp storedOp) = resolver.getThreshold(ESCROW_ID);
        assertEq(storedThreshold, threshold);
        assertEq(uint8(storedOp), op);
    }

    function test_RevertWhen_InvalidFeedAddress() public {
        bytes memory data = abi.encode(address(0), int256(1000), uint8(0), uint256(3600));

        vm.expectRevert(ChainlinkPriceFeedResolver.InvalidFeedAddress.selector);
        resolver.onConditionSet(ESCROW_ID, data);
    }

    function test_RevertWhen_ConditionAlreadySet() public {
        bytes memory data = abi.encode(address(mockFeed), int256(1000), uint8(0), uint256(3600));

        resolver.onConditionSet(ESCROW_ID, data);

        vm.expectRevert();
        resolver.onConditionSet(ESCROW_ID, data);
    }

    function test_GetLatestValue() public {
        bytes memory data = abi.encode(address(mockFeed), int256(1000), uint8(0), uint256(3600));
        resolver.onConditionSet(ESCROW_ID, data);

        (int256 value, uint256 timestamp) = resolver.getLatestValue(ESCROW_ID);

        assertEq(value, INITIAL_PRICE);
        assertEq(timestamp, block.timestamp);
    }

    function test_IsConditionMet_GreaterThan() public {
        int256 threshold = 1500 * 10 ** 8;
        bytes memory data =
            abi.encode(address(mockFeed), threshold, uint8(IOracleConditionResolver.ComparisonOp.GreaterThan), 3600);
        resolver.onConditionSet(ESCROW_ID, data);

        assertTrue(resolver.isConditionMet(ESCROW_ID));

        mockFeed.setAnswer(1000 * 10 ** 8);
        assertFalse(resolver.isConditionMet(ESCROW_ID));
    }

    function test_IsConditionMet_LessThan() public {
        int256 threshold = 2500 * 10 ** 8;
        bytes memory data =
            abi.encode(address(mockFeed), threshold, uint8(IOracleConditionResolver.ComparisonOp.LessThan), 3600);
        resolver.onConditionSet(ESCROW_ID, data);

        assertTrue(resolver.isConditionMet(ESCROW_ID));

        mockFeed.setAnswer(3000 * 10 ** 8);
        assertFalse(resolver.isConditionMet(ESCROW_ID));
    }

    function test_IsConditionMet_Equal() public {
        int256 threshold = 2000 * 10 ** 8;
        bytes memory data =
            abi.encode(address(mockFeed), threshold, uint8(IOracleConditionResolver.ComparisonOp.Equal), 3600);
        resolver.onConditionSet(ESCROW_ID, data);

        assertTrue(resolver.isConditionMet(ESCROW_ID));

        mockFeed.setAnswer(1999 * 10 ** 8);
        assertFalse(resolver.isConditionMet(ESCROW_ID));
    }

    function test_IsStale() public {
        bytes memory data = abi.encode(address(mockFeed), int256(1000), uint8(0), uint256(3600));
        resolver.onConditionSet(ESCROW_ID, data);

        assertFalse(resolver.isStale(ESCROW_ID));

        mockFeed.setUpdatedAt(block.timestamp - 7200);
        assertTrue(resolver.isStale(ESCROW_ID));
    }

    function test_IsConditionMet_ReturnsFalseWhenStale() public {
        bytes memory data = abi.encode(address(mockFeed), int256(1000), uint8(0), uint256(3600));
        resolver.onConditionSet(ESCROW_ID, data);

        mockFeed.setUpdatedAt(block.timestamp - 7200);

        assertFalse(resolver.isConditionMet(ESCROW_ID));
    }

    function test_SupportsInterface() public view {
        assertTrue(resolver.supportsInterface(type(IOracleConditionResolver).interfaceId));
    }
}
