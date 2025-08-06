// SPDX-License-Identifier: UNLICENSED
/* solhint-disable func-name-mixedcase */
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {CommonErrors} from "@concero/v2-contracts/contracts/common/CommonErrors.sol";
import {ConceroTypes} from "@concero/v2-contracts/contracts/ConceroClient/ConceroTypes.sol";

import {RateLimiter} from "contracts/LancaCanonicalBridge/RateLimiter.sol";

import {LCBridgeL1Test} from "./base/LCBridgeL1Test.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";

contract InboundRateLimitsTest is LCBridgeL1Test {
    function setUp() public override {
        super.setUp();

        _addDefaultPool();

        // Add funds to pool for withdrawals
        MockUSDC(usdc).mint(address(lancaCanonicalBridgePool), 10_000 * 1e6);
    }

    function test_setInboundRateLimit_RevertsUnauthorized() public {
        vm.expectRevert(CommonErrors.Unauthorized.selector);
        lancaCanonicalBridgeL1.setRateLimit(
            DST_CHAIN_SELECTOR,
            MAX_RATE_AMOUNT,
            REFILL_SPEED,
            false
        );
    }

    function test_setInboundRateLimit_Success() public {
        vm.expectEmit(true, true, true, true);
        emit RateLimiter.RateLimitSet(
            DST_CHAIN_SELECTOR,
            false, // isOutbound = false for inbound
            MAX_RATE_AMOUNT,
            REFILL_SPEED
        );

        // Set rate limit
        vm.prank(deployer);
        lancaCanonicalBridgeL1.setRateLimit(
            DST_CHAIN_SELECTOR,
            MAX_RATE_AMOUNT,
            REFILL_SPEED,
            false
        );

        (
            uint128 availableVolume,
            uint128 maxAmount,
            uint128 refillSpeed,
            uint32 lastUpdate,
            bool isActive
        ) = lancaCanonicalBridgeL1.getRateInfo(DST_CHAIN_SELECTOR, false);

        assertEq(availableVolume, MAX_RATE_AMOUNT); // Start with max available amount
        assertEq(maxAmount, MAX_RATE_AMOUNT);
        assertEq(refillSpeed, REFILL_SPEED);
        assertGt(lastUpdate, 0);
        assertTrue(isActive);

        // Test that setting again preserves available amount
        _performInboundTransfer(100 * 1e6);

        vm.prank(deployer);
        lancaCanonicalBridgeL1.setRateLimit(
            DST_CHAIN_SELECTOR,
            MAX_RATE_AMOUNT * 2, // Increase limit by 2x
            REFILL_SPEED,
            false
        );

        (availableVolume, , , , ) = lancaCanonicalBridgeL1.getRateInfo(DST_CHAIN_SELECTOR, false);
        // After consuming 100 USDC, 900 USDC should remain
        assertEq(availableVolume, MAX_RATE_AMOUNT - 100 * 1e6);
    }

    function test_inboundRateLimit_TransferWithinLimit() public {
        vm.prank(deployer);
        lancaCanonicalBridgeL1.setRateLimit(
            DST_CHAIN_SELECTOR,
            MAX_RATE_AMOUNT,
            REFILL_SPEED,
            false
        );

        _performInboundTransfer(500 * 1e6); // 500 USDC

        (uint128 availableVolume, , , , ) = lancaCanonicalBridgeL1.getRateInfo(
            DST_CHAIN_SELECTOR,
            false
        );
        assertEq(availableVolume, MAX_RATE_AMOUNT - 500 * 1e6); // 500 USDC available
    }

    function test_inboundRateLimit_RevertsIfRateLimitExceeded() public {
        vm.prank(deployer);
        lancaCanonicalBridgeL1.setRateLimit(
            DST_CHAIN_SELECTOR,
            MAX_RATE_AMOUNT,
            REFILL_SPEED,
            false
        );

        // First transfers accumulate
        _performInboundTransfer(300 * 1e6); // 300 USDC

        bytes memory messageWithFourHundred = _encodeBridgeParams(user, user, 400 * 1e6, 0, ""); // 400 USDC

        vm.prank(conceroRouter);
        lancaCanonicalBridgeL1.conceroReceive(
            DEFAULT_MESSAGE_ID,
            DST_CHAIN_SELECTOR,
            abi.encode(lancaBridgeMock),
            messageWithFourHundred
        );

        (uint128 availableVolume, , , , ) = lancaCanonicalBridgeL1.getRateInfo(
            DST_CHAIN_SELECTOR,
            false
        );
        assertEq(availableVolume, 300 * 1e6); // 300 USDC available

        // Next transfer should fail
        vm.expectRevert(
            abi.encodeWithSelector(RateLimiter.RateLimitExceeded.selector, 400 * 1e6, 300 * 1e6)
        );

        vm.prank(conceroRouter);
        lancaCanonicalBridgeL1.conceroReceive(
            DEFAULT_MESSAGE_ID,
            DST_CHAIN_SELECTOR,
            abi.encode(lancaBridgeMock),
            messageWithFourHundred
        );
    }

    function test_inboundRateLimit_RefillsOverTime() public {
        vm.prank(deployer);
        lancaCanonicalBridgeL1.setRateLimit(
            DST_CHAIN_SELECTOR,
            MAX_RATE_AMOUNT,
            REFILL_SPEED, // 10 USDC/sec
            false
        );

        // Consume all available amount
        _performInboundTransfer(MAX_RATE_AMOUNT);

        (uint128 availableVolume, , , , ) = lancaCanonicalBridgeL1.getRateInfo(
            DST_CHAIN_SELECTOR,
            false
        );
        assertEq(availableVolume, 0); // Not enough availableVolume amount

        // 60 seconds pass = 600 USDC refill
        vm.warp(block.timestamp + 60);

        // Check that it refilled
        (availableVolume, , , , ) = lancaCanonicalBridgeL1.getRateInfo(DST_CHAIN_SELECTOR, false);
        assertEq(availableVolume, 600 * 1e6); // Should refill 60 sec * 10 USDC/sec = 600 USDC

        // Check that we can use the refilled amount
        bytes memory message = _encodeBridgeParams(user, user, 600 * 1e6, 0, ""); // Should pass successfully

        vm.prank(conceroRouter);
        lancaCanonicalBridgeL1.conceroReceive(
            DEFAULT_MESSAGE_ID,
            DST_CHAIN_SELECTOR,
            abi.encode(lancaBridgeMock),
            message
        );

        (uint128 finalAvailable, , , , ) = lancaCanonicalBridgeL1.getRateInfo(
            DST_CHAIN_SELECTOR,
            false
        );
        assertEq(finalAvailable, 0); // Again empty after transfer
    }

    function test_inboundRateLimit_CapAtMaxAmount() public {
        vm.prank(deployer);
        lancaCanonicalBridgeL1.setRateLimit(
            DST_CHAIN_SELECTOR,
            MAX_RATE_AMOUNT,
            REFILL_SPEED,
            false
        );

        // Don't touch the rate limit for 1000 seconds
        vm.warp(block.timestamp + 1000);

        (uint128 availableVolume, , , , ) = lancaCanonicalBridgeL1.getRateInfo(
            DST_CHAIN_SELECTOR,
            false
        );
        // Should be limited to max amount, not overflow
        assertEq(availableVolume, MAX_RATE_AMOUNT);
    }

    function test_inboundRateLimit_DisabledWithZeroMaxAmount() public {
        vm.prank(deployer);
        lancaCanonicalBridgeL1.setRateLimit(DST_CHAIN_SELECTOR, 0, 0, false);

        _addDefaultDstBridge();
        bytes memory message = _encodeBridgeParams(user, user, 1000 * 1e6, 0, "");

        // Transfers should be blocked when maxAmount = 0 (soft pause)
        vm.expectRevert(
            abi.encodeWithSelector(RateLimiter.RateLimitExceeded.selector, 1000 * 1e6, 0)
        );

        vm.prank(conceroRouter);
        lancaCanonicalBridgeL1.conceroReceive(
            DEFAULT_MESSAGE_ID,
            DST_CHAIN_SELECTOR,
            abi.encode(lancaBridgeMock),
            message
        );

        (, uint128 maxAmount, uint128 refillSpeed, , bool isActive) = lancaCanonicalBridgeL1
            .getRateInfo(DST_CHAIN_SELECTOR, false);

        assertEq(maxAmount, 0);
        assertEq(refillSpeed, 0);
        assertFalse(isActive);
    }

    function test_inboundRateLimit_InvalidConfigRevertsIfSpeedExceedsCapacity() public {
        vm.prank(deployer);
        vm.expectRevert(
            abi.encodeWithSelector(
                RateLimiter.InvalidRateLimitConfig.selector,
                100 * 1e6,
                200 * 1e6
            )
        );
        lancaCanonicalBridgeL1.setRateLimit(
            DST_CHAIN_SELECTOR,
            100 * 1e6, // maxAmount
            200 * 1e6, // refillSpeed greater than maxAmount
            false
        );

        // But it should be allowed when maxAmount = 0 (disabled state)
        vm.prank(deployer);
        lancaCanonicalBridgeL1.setRateLimit(
            DST_CHAIN_SELECTOR,
            0, // maxAmount = 0 (disabled)
            200 * 1e6, // refillSpeed can be anything when disabled
            false
        );

        (, uint128 maxAmount, uint128 refillSpeed, , bool isActive) = lancaCanonicalBridgeL1
            .getRateInfo(DST_CHAIN_SELECTOR, false);

        assertEq(maxAmount, 0);
        assertEq(refillSpeed, 200 * 1e6);
        assertFalse(isActive);
    }

    function test_inboundRateLimit_PartialRefill() public {
        vm.prank(deployer);
        lancaCanonicalBridgeL1.setRateLimit(
            DST_CHAIN_SELECTOR,
            MAX_RATE_AMOUNT,
            REFILL_SPEED, // 10 USDC/sec
            false
        );

        // Consume half
        _performInboundTransfer(500 * 1e6);

        (uint128 availableVolume, , , , ) = lancaCanonicalBridgeL1.getRateInfo(
            DST_CHAIN_SELECTOR,
            false
        );
        assertEq(availableVolume, 500 * 1e6);

        // Wait 30 seconds = 300 USDC refill
        vm.warp(block.timestamp + 30);

        (availableVolume, , , , ) = lancaCanonicalBridgeL1.getRateInfo(DST_CHAIN_SELECTOR, false);
        assertEq(availableVolume, 800 * 1e6); // 500 + 300 = 800
    }

    function test_inboundRateLimit_UpdateConfigPreservesTokens() public {
        vm.prank(deployer);
        lancaCanonicalBridgeL1.setRateLimit(
            DST_CHAIN_SELECTOR,
            MAX_RATE_AMOUNT,
            REFILL_SPEED,
            false
        );

        // Consume 300 USDC
        _performInboundTransfer(300 * 1e6);

        (uint128 availableBefore, , , , ) = lancaCanonicalBridgeL1.getRateInfo(
            DST_CHAIN_SELECTOR,
            false
        );
        assertEq(availableBefore, 700 * 1e6);

        // Update configuration
        vm.prank(deployer);
        lancaCanonicalBridgeL1.setRateLimit(
            DST_CHAIN_SELECTOR,
            MAX_RATE_AMOUNT,
            REFILL_SPEED * 2, // Increase speed
            false
        );

        // Available amount should be preserved
        (uint128 availableAfter, , uint128 newRefillSpeed, , ) = lancaCanonicalBridgeL1.getRateInfo(
            DST_CHAIN_SELECTOR,
            false
        );

        assertEq(availableAfter, 700 * 1e6);
        assertEq(newRefillSpeed, REFILL_SPEED * 2);
    }

    // --- Helper functions ---

    function _performInboundTransfer(uint256 amount) internal {
        _addDefaultDstBridge();
        bytes memory message = _encodeBridgeParams(user, user, amount, 0, "");

        vm.prank(conceroRouter);
        lancaCanonicalBridgeL1.conceroReceive(
            DEFAULT_MESSAGE_ID,
            DST_CHAIN_SELECTOR,
            abi.encode(lancaBridgeMock),
            message
        );
    }
}
