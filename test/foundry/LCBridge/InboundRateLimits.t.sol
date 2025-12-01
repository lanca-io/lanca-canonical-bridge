// SPDX-License-Identifier: UNLICENSED
/* solhint-disable func-name-mixedcase */
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {CommonErrors} from "@concero/v2-contracts/contracts/common/CommonErrors.sol";
import {IConceroRouter} from "@concero/v2-contracts/contracts/interfaces/IConceroRouter.sol";
import {MessageCodec} from "@concero/v2-contracts/contracts/common/libraries/MessageCodec.sol";

import {BridgeCodec} from "contracts/common/libraries/BridgeCodec.sol";
import {LancaCanonicalBridge} from "contracts/LancaCanonicalBridge/LancaCanonicalBridge.sol";
import {RateLimiter} from "contracts/LancaCanonicalBridge/RateLimiter.sol";

import {LCBridgeBase} from "./LCBridgeBase.sol";
import {MockUSDCe} from "../mocks/MockUSDCe.sol";

contract InboundRateLimitsTest is LCBridgeBase {
    using MessageCodec for IConceroRouter.MessageRequest;

    function setUp() public override {
        super.setUp();
        // Add funds to bridge contract for minting
        MockUSDCe(address(s_usdcE)).setMinter(address(lancaCanonicalBridge));
    }

    function test_setInboundRateLimit_RevertsUnauthorized() public {
        vm.expectRevert(
            _constructAccessControlError(address(this), lancaCanonicalBridge.RATE_LIMIT_ADMIN())
        );
        lancaCanonicalBridge.setRateLimit(SRC_CHAIN_SELECTOR, MAX_RATE_AMOUNT, REFILL_SPEED, false);
    }

    function test_setInboundRateLimit_Success() public {
        vm.expectEmit(true, true, true, true);
        emit RateLimiter.RateLimitSet(SRC_CHAIN_SELECTOR, false, MAX_RATE_AMOUNT, REFILL_SPEED);

        vm.prank(s_deployer);
        lancaCanonicalBridge.setRateLimit(SRC_CHAIN_SELECTOR, MAX_RATE_AMOUNT, REFILL_SPEED, false);

        (
            uint128 availableVolume,
            uint128 maxAmount,
            uint128 refillSpeed,
            uint32 lastUpdate,
            bool isActive
        ) = lancaCanonicalBridge.getRateInfo(SRC_CHAIN_SELECTOR, false);

        assertEq(availableVolume, MAX_RATE_AMOUNT);
        assertEq(maxAmount, MAX_RATE_AMOUNT);
        assertEq(refillSpeed, REFILL_SPEED);
        assertGt(lastUpdate, 0);
        assertTrue(isActive);
    }

    function test_setInboundRateLimit_PreservesStateOnConfigurationUpdate() public {
        vm.prank(s_deployer);
        lancaCanonicalBridge.setRateLimit(SRC_CHAIN_SELECTOR, MAX_RATE_AMOUNT, REFILL_SPEED, false);

        // Consume some rate
        _performReceive(100 * 1e6);

        (uint128 availableBefore, , , , ) = lancaCanonicalBridge.getRateInfo(
            SRC_CHAIN_SELECTOR,
            false
        );
        assertEq(availableBefore, MAX_RATE_AMOUNT - 100 * 1e6);

        // Update configuration
        vm.prank(s_deployer);
        lancaCanonicalBridge.setRateLimit(SRC_CHAIN_SELECTOR, MAX_RATE_AMOUNT, REFILL_SPEED, false);

        // State should be preserved
        (uint128 availableAfter, , , , ) = lancaCanonicalBridge.getRateInfo(
            SRC_CHAIN_SELECTOR,
            false
        );
        assertEq(availableAfter, MAX_RATE_AMOUNT - 100 * 1e6);
    }

    function test_inboundRateLimit_ReceiveWithinLimit() public {
        vm.prank(s_deployer);
        lancaCanonicalBridge.setRateLimit(SRC_CHAIN_SELECTOR, MAX_RATE_AMOUNT, REFILL_SPEED, false);

        _performReceive(500 * 1e6); // 500 USDC

        (uint128 availableVolume, , , , ) = lancaCanonicalBridge.getRateInfo(
            SRC_CHAIN_SELECTOR,
            false
        );
        assertEq(availableVolume, 500 * 1e6);
    }

    function test_inboundRateLimit_RevertsIfRateExceeded() public {
        vm.prank(s_deployer);
        lancaCanonicalBridge.setRateLimit(SRC_CHAIN_SELECTOR, MAX_RATE_AMOUNT, REFILL_SPEED, false);

        // First receives accumulate
        _performReceive(300 * 1e6); // 300 USDC
        _performReceive(400 * 1e6); // 400 USDC

        (uint128 availableVolume, , , , ) = lancaCanonicalBridge.getRateInfo(
            SRC_CHAIN_SELECTOR,
            false
        );
        assertEq(availableVolume, 300 * 1e6); // 300 USDC left

        // Next receive should fail
        IConceroRouter.MessageRequest memory messageRequest = _buildMessageRequest(
            BridgeCodec.encodeBridgeData(
                s_user,
                400 * 1e6,
                MessageCodec.encodeEvmDstChainData(s_user, 0),
                ""
            ),
            SRC_CHAIN_SELECTOR,
            address(lancaCanonicalBridge)
        );

        vm.expectRevert(
            abi.encodeWithSelector(RateLimiter.RateLimitExceeded.selector, 400 * 1e6, 300 * 1e6)
        );

        vm.prank(s_conceroRouter);
        lancaCanonicalBridge.conceroReceive(
            messageRequest.toMessageReceiptBytes(SRC_CHAIN_SELECTOR, s_lancaBridgeL1Mock, NONCE),
            s_validationChecks,
            s_validatorLibs,
            s_relayerLib
        );
    }

    function test_inboundRateLimit_RefillOverTime() public {
        vm.prank(s_deployer);
        lancaCanonicalBridge.setRateLimit(SRC_CHAIN_SELECTOR, MAX_RATE_AMOUNT, REFILL_SPEED, false);

        // Consume all available rate
        _performReceive(MAX_RATE_AMOUNT);

        (uint128 availableVolume, , , , ) = lancaCanonicalBridge.getRateInfo(
            SRC_CHAIN_SELECTOR,
            false
        );
        assertEq(availableVolume, 0);

        // Wait for 50 seconds -> should refill 500 USDC
        vm.warp(block.timestamp + 50);

        // Should now be able to receive 500 USDC
        _performReceive(500 * 1e6);

        (availableVolume, , , , ) = lancaCanonicalBridge.getRateInfo(SRC_CHAIN_SELECTOR, false);
        assertEq(availableVolume, 0);
    }

    function test_inboundRateLimit_MaxAmountCapping() public {
        vm.prank(s_deployer);
        lancaCanonicalBridge.setRateLimit(SRC_CHAIN_SELECTOR, MAX_RATE_AMOUNT, REFILL_SPEED, false);

        // Consume half the rate
        _performReceive(500 * 1e6);

        // Wait for a very long time (should cap at maxAmount)
        vm.warp(block.timestamp + 1000);

        (uint128 availableVolume, , , , ) = lancaCanonicalBridge.getRateInfo(
            SRC_CHAIN_SELECTOR,
            false
        );
        assertEq(availableVolume, MAX_RATE_AMOUNT);
    }

    function test_inboundRateLimit_DisabledWithZeroMaxAmount() public {
        vm.prank(s_deployer);
        lancaCanonicalBridge.setRateLimit(SRC_CHAIN_SELECTOR, 0, REFILL_SPEED, false);

        // Transfers should be blocked when maxAmount = 0 (soft pause)
        IConceroRouter.MessageRequest memory messageRequest = _buildMessageRequest(
            BridgeCodec.encodeBridgeData(
                s_user,
                1000 * 1e6,
                MessageCodec.encodeEvmDstChainData(s_user, 0),
                ""
            ),
            SRC_CHAIN_SELECTOR,
            address(lancaCanonicalBridge)
        );

        vm.expectRevert(
            abi.encodeWithSelector(RateLimiter.RateLimitExceeded.selector, 1000 * 1e6, 0)
        );

        vm.prank(s_conceroRouter);
        lancaCanonicalBridge.conceroReceive(
            messageRequest.toMessageReceiptBytes(SRC_CHAIN_SELECTOR, s_lancaBridgeL1Mock, NONCE),
            s_validationChecks,
            s_validatorLibs,
            s_relayerLib
        );

        (uint128 availableVolume, uint128 maxAmount, , , bool isActive) = LancaCanonicalBridge(
            address(lancaCanonicalBridge)
        ).getRateInfo(SRC_CHAIN_SELECTOR, false);
        assertEq(maxAmount, 0);
        assertFalse(isActive);
        assertEq(availableVolume, 0);
    }

    function test_inboundRateLimit_InvalidConfiguration() public {
        vm.expectRevert(
            abi.encodeWithSelector(RateLimiter.InvalidRateLimitConfig.selector, 50e6, 100e6)
        );

        vm.prank(s_deployer);
        lancaCanonicalBridge.setRateLimit(
            SRC_CHAIN_SELECTOR,
            50e6, // maxAmount
            100e6, // refillSpeed > maxAmount
            false
        );

        // But it should be allowed when maxAmount = 0 (disabled state)
        vm.prank(s_deployer);
        lancaCanonicalBridge.setRateLimit(
            SRC_CHAIN_SELECTOR,
            0, // maxAmount = 0 (disabled)
            100e6, // refillSpeed can be anything when disabled
            false
        );

        (
            uint128 availableVolume,
            uint128 maxAmount,
            uint128 refillSpeed,
            ,
            bool isActive
        ) = lancaCanonicalBridge.getRateInfo(SRC_CHAIN_SELECTOR, false);
        assertEq(maxAmount, 0);
        assertEq(refillSpeed, 100e6);
        assertFalse(isActive);
        assertEq(availableVolume, 0);
    }

    function test_inboundRateLimit_PartialRefill() public {
        vm.prank(s_deployer);
        lancaCanonicalBridge.setRateLimit(SRC_CHAIN_SELECTOR, MAX_RATE_AMOUNT, REFILL_SPEED, false);

        // Consume most of the rate
        _performReceive(900 * 1e6);

        (uint128 availableVolume, , , , ) = lancaCanonicalBridge.getRateInfo(
            SRC_CHAIN_SELECTOR,
            false
        );
        assertEq(availableVolume, 100 * 1e6);

        // Wait for partial refill (20 seconds = 200 USDC)
        vm.warp(block.timestamp + 20);

        // Should be able to receive 300 USDC (100 + 200)
        _performReceive(300 * 1e6);

        (availableVolume, , , , ) = lancaCanonicalBridge.getRateInfo(SRC_CHAIN_SELECTOR, false);

        assertEq(availableVolume, 0);
    }

    function test_inboundRateLimit_ReducingMaxAmountCapsAvailable() public {
        vm.prank(s_deployer);
        lancaCanonicalBridge.setRateLimit(
            SRC_CHAIN_SELECTOR,
            MAX_RATE_AMOUNT, // 1000 USDC
            REFILL_SPEED,
            false
        );

        // Consume some rate, leaving 800 USDC available
        _performReceive(200 * 1e6);

        (uint128 availableBefore, , , , ) = lancaCanonicalBridge.getRateInfo(
            SRC_CHAIN_SELECTOR,
            false
        );
        assertEq(availableBefore, 800 * 1e6);

        // Reduce max amount to 500 USDC (less than current available)
        vm.prank(s_deployer);
        lancaCanonicalBridge.setRateLimit(
            SRC_CHAIN_SELECTOR,
            500e6, // 500 USDC (new limit)
            REFILL_SPEED,
            false
        );

        // Available should be capped at new maxAmount
        (uint128 availableAfter, uint128 maxAmount, , , ) = lancaCanonicalBridge.getRateInfo(
            SRC_CHAIN_SELECTOR,
            false
        );
        assertEq(maxAmount, 500e6);
        assertEq(availableAfter, 500e6); // Capped at new limit, not 800

        // Should only be able to receive up to the new limit
        _performReceive(500 * 1e6);

        (uint128 finalAvailable, , , , ) = lancaCanonicalBridge.getRateInfo(
            SRC_CHAIN_SELECTOR,
            false
        );
        assertEq(finalAvailable, 0);
    }

    // --- Helper functions ---

    function _performReceive(uint256 amount) internal {
        IConceroRouter.MessageRequest memory messageRequest = _buildMessageRequest(
            BridgeCodec.encodeBridgeData(
                s_user,
                amount,
                MessageCodec.encodeEvmDstChainData(s_user, 0),
                ""
            ),
            SRC_CHAIN_SELECTOR,
            address(lancaCanonicalBridge)
        );

        vm.prank(s_conceroRouter);
        lancaCanonicalBridge.conceroReceive(
            messageRequest.toMessageReceiptBytes(SRC_CHAIN_SELECTOR, s_lancaBridgeL1Mock, NONCE),
            s_validationChecks,
            s_validatorLibs,
            s_relayerLib
        );
    }
}
