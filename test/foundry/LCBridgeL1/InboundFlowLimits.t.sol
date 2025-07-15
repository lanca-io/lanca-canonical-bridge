// SPDX-License-Identifier: UNLICENSED
/* solhint-disable func-name-mixedcase */
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {CommonErrors} from "@concero/messaging-contracts-v2/contracts/common/CommonErrors.sol";
import {ConceroTypes} from "@concero/messaging-contracts-v2/contracts/ConceroClient/ConceroTypes.sol";

import {FlowLimiter} from "contracts/LancaCanonicalBridge/FlowLimiter.sol";

import {LCBridgeL1Test} from "./base/LCBridgeL1Test.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";

contract InboundFlowLimitsTest is LCBridgeL1Test {
    function setUp() public override {
        super.setUp();

        _addDefaultPool();

        // Add funds to pool for withdrawals
        MockUSDC(usdc).mint(address(lancaCanonicalBridgePool), 10_000 * 1e6);
    }

    function test_setInboundFlowLimit_RevertsUnauthorized() public {
        vm.expectRevert(CommonErrors.Unauthorized.selector);
        lancaCanonicalBridgeL1.setInboundFlowLimit(
            DST_CHAIN_SELECTOR,
            MAX_FLOW_AMOUNT,
            REFILL_SPEED
        );
    }

    function test_setInboundFlowLimit_Success() public {
        vm.expectEmit(true, true, true, true);
        emit FlowLimiter.FlowLimitSet(
            DST_CHAIN_SELECTOR,
            false, // isOutbound = false for inbound
            MAX_FLOW_AMOUNT,
            REFILL_SPEED
        );

        // Set flow limit
        vm.prank(deployer);
        lancaCanonicalBridgeL1.setInboundFlowLimit(
            DST_CHAIN_SELECTOR,
            MAX_FLOW_AMOUNT,
            REFILL_SPEED
        );

        (
            uint128 available,
            uint128 maxAmount,
            uint128 refillSpeed,
            uint32 lastUpdate,
            bool isActive
        ) = lancaCanonicalBridgeL1.getInboundFlowInfo(DST_CHAIN_SELECTOR);

        assertEq(available, MAX_FLOW_AMOUNT); // Start with max available amount
        assertEq(maxAmount, MAX_FLOW_AMOUNT);
        assertEq(refillSpeed, REFILL_SPEED);
        assertGt(lastUpdate, 0);
        assertTrue(isActive);

        // Test that setting again preserves available amount
        _performInboundTransfer(100 * 1e6);

        vm.prank(deployer);
        lancaCanonicalBridgeL1.setInboundFlowLimit(
            DST_CHAIN_SELECTOR,
            MAX_FLOW_AMOUNT * 2, // Increase limit by 2x
            REFILL_SPEED
        );

        (available, , , , ) = lancaCanonicalBridgeL1.getInboundFlowInfo(DST_CHAIN_SELECTOR);
        // After consuming 100 USDC, 900 USDC should remain
        assertEq(available, MAX_FLOW_AMOUNT - 100 * 1e6);
    }

    function test_inboundFlowLimit_TransferWithinLimit() public {
        vm.prank(deployer);
        lancaCanonicalBridgeL1.setInboundFlowLimit(
            DST_CHAIN_SELECTOR,
            MAX_FLOW_AMOUNT,
            REFILL_SPEED
        );

        _performInboundTransfer(500 * 1e6); // 500 USDC

        (uint128 available, , , , ) = lancaCanonicalBridgeL1.getInboundFlowInfo(DST_CHAIN_SELECTOR);
        assertEq(available, MAX_FLOW_AMOUNT - 500 * 1e6); // 500 USDC available
    }

    function test_inboundFlowLimit_RevertsIfFlowLimitExceeded() public {
        vm.prank(deployer);
        lancaCanonicalBridgeL1.setInboundFlowLimit(
            DST_CHAIN_SELECTOR,
            MAX_FLOW_AMOUNT,
            REFILL_SPEED
        );

        // First transfers accumulate
        _performInboundTransfer(300 * 1e6); // 300 USDC

        bytes memory messageWithFourHundred = abi.encode(user, 400 * 1e6); // 400 USDC

        vm.prank(conceroRouter);
        lancaCanonicalBridgeL1.conceroReceive(
            DEFAULT_MESSAGE_ID,
            DST_CHAIN_SELECTOR,
            abi.encode(lancaBridgeMock),
            messageWithFourHundred
        );

        (uint128 available, , , , ) = lancaCanonicalBridgeL1.getInboundFlowInfo(DST_CHAIN_SELECTOR);
        assertEq(available, 300 * 1e6); // 300 USDC available

        // Next transfer should fail
        vm.expectRevert(
            abi.encodeWithSelector(FlowLimiter.FlowLimitExceeded.selector, 400 * 1e6, 300 * 1e6)
        );

        vm.prank(conceroRouter);
        lancaCanonicalBridgeL1.conceroReceive(
            DEFAULT_MESSAGE_ID,
            DST_CHAIN_SELECTOR,
            abi.encode(lancaBridgeMock),
            messageWithFourHundred
        );
    }

    function test_inboundFlowLimit_RefillsOverTime() public {
        vm.prank(deployer);
        lancaCanonicalBridgeL1.setInboundFlowLimit(
            DST_CHAIN_SELECTOR,
            MAX_FLOW_AMOUNT,
            REFILL_SPEED // 10 USDC/sec
        );

        // Consume all available amount
        _performInboundTransfer(MAX_FLOW_AMOUNT);

        (uint128 available, , , , ) = lancaCanonicalBridgeL1.getInboundFlowInfo(DST_CHAIN_SELECTOR);
        assertEq(available, 0); // Not enough available amount

        // 60 seconds pass = 600 USDC refill
        vm.warp(block.timestamp + 60);

        // Check that it refilled
        (available, , , , ) = lancaCanonicalBridgeL1.getInboundFlowInfo(DST_CHAIN_SELECTOR);
        assertEq(available, 600 * 1e6); // Should refill 60 sec * 10 USDC/sec = 600 USDC

        // Check that we can use the refilled amount
        bytes memory message = abi.encode(user, 600 * 1e6); // Should pass successfully

        vm.prank(conceroRouter);
        lancaCanonicalBridgeL1.conceroReceive(
            DEFAULT_MESSAGE_ID,
            DST_CHAIN_SELECTOR,
            abi.encode(lancaBridgeMock),
            message
        );

        (uint128 finalAvailable, , , , ) = lancaCanonicalBridgeL1.getInboundFlowInfo(
            DST_CHAIN_SELECTOR
        );
        assertEq(finalAvailable, 0); // Again empty after transfer
    }

    function test_inboundFlowLimit_CapAtMaxAmount() public {
        vm.prank(deployer);
        lancaCanonicalBridgeL1.setInboundFlowLimit(
            DST_CHAIN_SELECTOR,
            MAX_FLOW_AMOUNT,
            REFILL_SPEED
        );

        // Don't touch the flow limit for 1000 seconds
        vm.warp(block.timestamp + 1000);

        (uint128 available, , , , ) = lancaCanonicalBridgeL1.getInboundFlowInfo(DST_CHAIN_SELECTOR);
        // Should be limited to max amount, not overflow
        assertEq(available, MAX_FLOW_AMOUNT);
    }

    function test_inboundFlowLimit_DisabledWithZeroMaxAmount() public {
        vm.prank(deployer);
        lancaCanonicalBridgeL1.setInboundFlowLimit(DST_CHAIN_SELECTOR, 0, 0);

        _addDefaultDstBridge();
        bytes memory message = abi.encode(user, 1000 * 1e6);

        // Transfers should be blocked when maxAmount = 0 (soft pause)
        vm.expectRevert(
            abi.encodeWithSelector(FlowLimiter.FlowLimitExceeded.selector, 1000 * 1e6, 0)
        );

        vm.prank(conceroRouter);
        lancaCanonicalBridgeL1.conceroReceive(
            DEFAULT_MESSAGE_ID,
            DST_CHAIN_SELECTOR,
            abi.encode(lancaBridgeMock),
            message
        );

        (, uint128 maxAmount, uint128 refillSpeed, , bool isActive) = lancaCanonicalBridgeL1
            .getInboundFlowInfo(DST_CHAIN_SELECTOR);

        assertEq(maxAmount, 0);
        assertEq(refillSpeed, 0);
        assertFalse(isActive);
    }

    function test_inboundFlowLimit_InvalidConfigRevertsIfSpeedExceedsCapacity() public {
        vm.prank(deployer);
        vm.expectRevert(
            abi.encodeWithSelector(FlowLimiter.InvalidFlowConfig.selector, 100 * 1e6, 200 * 1e6)
        );
        lancaCanonicalBridgeL1.setInboundFlowLimit(
            DST_CHAIN_SELECTOR,
            100 * 1e6, // maxAmount
            200 * 1e6 // refillSpeed greater than maxAmount
        );

        // But it should be allowed when maxAmount = 0 (disabled state)
        vm.prank(deployer);
        lancaCanonicalBridgeL1.setInboundFlowLimit(
            DST_CHAIN_SELECTOR,
            0, // maxAmount = 0 (disabled)
            200 * 1e6 // refillSpeed can be anything when disabled
        );

        (, uint128 maxAmount, uint128 refillSpeed, , bool isActive) = lancaCanonicalBridgeL1
            .getInboundFlowInfo(DST_CHAIN_SELECTOR);

        assertEq(maxAmount, 0);
        assertEq(refillSpeed, 200 * 1e6);
        assertFalse(isActive);
    }

    function test_inboundFlowLimit_PartialRefill() public {
        vm.prank(deployer);
        lancaCanonicalBridgeL1.setInboundFlowLimit(
            DST_CHAIN_SELECTOR,
            MAX_FLOW_AMOUNT,
            REFILL_SPEED // 10 USDC/sec
        );

        // Consume half
        _performInboundTransfer(500 * 1e6);

        (uint128 available, , , , ) = lancaCanonicalBridgeL1.getInboundFlowInfo(DST_CHAIN_SELECTOR);
        assertEq(available, 500 * 1e6);

        // Wait 30 seconds = 300 USDC refill
        vm.warp(block.timestamp + 30);

        (available, , , , ) = lancaCanonicalBridgeL1.getInboundFlowInfo(DST_CHAIN_SELECTOR);
        assertEq(available, 800 * 1e6); // 500 + 300 = 800
    }

    function test_inboundFlowLimit_UpdateConfigPreservesTokens() public {
        vm.prank(deployer);
        lancaCanonicalBridgeL1.setInboundFlowLimit(
            DST_CHAIN_SELECTOR,
            MAX_FLOW_AMOUNT,
            REFILL_SPEED
        );

        // Consume 300 USDC
        _performInboundTransfer(300 * 1e6);

        (uint128 availableBefore, , , , ) = lancaCanonicalBridgeL1.getInboundFlowInfo(
            DST_CHAIN_SELECTOR
        );
        assertEq(availableBefore, 700 * 1e6);

        // Update configuration
        vm.prank(deployer);
        lancaCanonicalBridgeL1.setInboundFlowLimit(
            DST_CHAIN_SELECTOR,
            MAX_FLOW_AMOUNT,
            REFILL_SPEED * 2 // Increase speed
        );

        // Available amount should be preserved
        (uint128 availableAfter, , uint128 newRefillSpeed, , ) = lancaCanonicalBridgeL1
            .getInboundFlowInfo(DST_CHAIN_SELECTOR);

        assertEq(availableAfter, 700 * 1e6);
        assertEq(newRefillSpeed, REFILL_SPEED * 2);
    }

    // --- Helper functions ---

    function _performInboundTransfer(uint256 amount) internal {
        _addDefaultDstBridge();
        bytes memory message = abi.encode(user, amount);

        vm.prank(conceroRouter);
        lancaCanonicalBridgeL1.conceroReceive(
            DEFAULT_MESSAGE_ID,
            DST_CHAIN_SELECTOR,
            abi.encode(lancaBridgeMock),
            message
        );
    }
}
