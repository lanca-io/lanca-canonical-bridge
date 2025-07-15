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

import {RateLimiter} from "contracts/LancaCanonicalBridge/RateLimiter.sol";
import {LancaCanonicalBridge} from "contracts/LancaCanonicalBridge/LancaCanonicalBridge.sol";

import {LCBridgeTest} from "./base/LCBridgeTest.sol";
import {MockUSDCe} from "../mocks/MockUSDCe.sol";

contract OutboundRateLimitsTest is LCBridgeTest {
    function setUp() public override {
        super.setUp();
        deal(address(usdcE), user, 10_000 * 1e6); // 10K USDC
    }

    function test_setOutboundRateLimit_RevertsUnauthorized() public {
        vm.expectRevert(CommonErrors.Unauthorized.selector);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setOutboundRateLimit(
            MAX_RATE_AMOUNT,
            REFILL_SPEED
        );
    }

    function test_setOutboundRateLimit_Success() public {
        vm.expectEmit(true, true, true, true);
        emit RateLimiter.RateLimitSet(SRC_CHAIN_SELECTOR, true, MAX_RATE_AMOUNT, REFILL_SPEED);

        vm.prank(deployer);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setOutboundRateLimit(
            MAX_RATE_AMOUNT,
            REFILL_SPEED
        );

        (
            uint128 availableVolume,
            uint128 maxAmount,
            uint128 refillSpeed,
            uint32 lastUpdate,
            bool isActive
        ) = LancaCanonicalBridge(address(lancaCanonicalBridge)).getOutboundRateInfo();

        assertEq(availableVolume, MAX_RATE_AMOUNT);
        assertEq(maxAmount, MAX_RATE_AMOUNT);
        assertEq(refillSpeed, REFILL_SPEED);
        assertGt(lastUpdate, 0);
        assertTrue(isActive);
    }

    function test_setOutboundRateLimit_PreservesStateOnConfigurationUpdate() public {
        vm.prank(deployer);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setOutboundRateLimit(
            MAX_RATE_AMOUNT,
            REFILL_SPEED
        );

        // Consume some rate
        _performTransfer(100 * 1e6);

        (uint128 availableBefore, , , , ) = LancaCanonicalBridge(address(lancaCanonicalBridge))
            .getOutboundRateInfo();
        assertEq(availableBefore, MAX_RATE_AMOUNT - 100 * 1e6);

        // Update configuration
        vm.prank(deployer);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setOutboundRateLimit(
            MAX_RATE_AMOUNT,
            REFILL_SPEED
        );

        // State should be preserved
        (uint128 availableAfter, , , , ) = LancaCanonicalBridge(address(lancaCanonicalBridge))
            .getOutboundRateInfo();
        assertEq(availableAfter, MAX_RATE_AMOUNT - 100 * 1e6);
    }

    function test_outboundRateLimit_TransferWithinLimit() public {
        vm.prank(deployer);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setOutboundRateLimit(
            MAX_RATE_AMOUNT,
            REFILL_SPEED
        );

        _performTransfer(500 * 1e6); // 500 USDC

        (uint128 availableVolume, , , , ) = LancaCanonicalBridge(address(lancaCanonicalBridge))
            .getOutboundRateInfo();
        assertEq(availableVolume, 500 * 1e6);
    }

    function test_outboundRateLimit_RevertsIfRateExceeded() public {
        vm.prank(deployer);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setOutboundRateLimit(
            MAX_RATE_AMOUNT,
            REFILL_SPEED
        );

        _performTransfer(300 * 1e6); // 300 USDC
        _performTransfer(400 * 1e6); // 400 USDC

        (uint128 availableVolume, , , , ) = LancaCanonicalBridge(address(lancaCanonicalBridge))
            .getOutboundRateInfo();
        assertEq(availableVolume, 300 * 1e6); // 300 USDC left

        // Next transfer should fail
        uint256 messageFee = _getMessageFee();
        vm.startPrank(user);
        MockUSDCe(usdcE).approve(address(lancaCanonicalBridge), 400 * 1e6);

        vm.expectRevert(
            abi.encodeWithSelector(RateLimiter.RateLimitExceeded.selector, 400 * 1e6, 300 * 1e6)
        );
        LancaCanonicalBridge(address(lancaCanonicalBridge)).sendToken{value: messageFee}(
            400 * 1e6,
            address(0),
            ConceroTypes.EvmDstChainData({receiver: lancaBridgeL1Mock, gasLimit: GAS_LIMIT})
        );
        vm.stopPrank();
    }

    function test_outboundRateLimit_RefillOverTime() public {
        vm.prank(deployer);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setOutboundRateLimit(
            MAX_RATE_AMOUNT,
            REFILL_SPEED
        );

        // Consume all available rate
        _performTransfer(MAX_RATE_AMOUNT);

        (uint128 availableVolume, , , , ) = LancaCanonicalBridge(address(lancaCanonicalBridge))
            .getOutboundRateInfo();
        assertEq(availableVolume, 0);

        // Wait for 50 seconds -> should refill 500 USDC
        vm.warp(block.timestamp + 50);

        // Should now be able to transfer 500 USDC
        _performTransfer(500 * 1e6);

        (availableVolume, , , , ) = LancaCanonicalBridge(address(lancaCanonicalBridge))
            .getOutboundRateInfo();
        assertEq(availableVolume, 0);
    }

    function test_outboundRateLimit_MaxAmountCapping() public {
        vm.prank(deployer);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setOutboundRateLimit(
            MAX_RATE_AMOUNT,
            REFILL_SPEED
        );

        // Consume half the rate
        _performTransfer(500 * 1e6);

        // Wait for a very long time (should cap at maxAmount)
        vm.warp(block.timestamp + 1000);

        (uint128 availableVolume, , , , ) = LancaCanonicalBridge(address(lancaCanonicalBridge))
            .getOutboundRateInfo();
        assertEq(availableVolume, MAX_RATE_AMOUNT);
    }

    function test_outboundRateLimit_DisabledWithZeroMaxAmount() public {
        vm.prank(deployer);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setOutboundRateLimit(0, REFILL_SPEED);

        // Transfers should be blocked when maxAmount = 0 (soft pause)
        uint256 messageFee = _getMessageFee();
        vm.startPrank(user);
        MockUSDCe(usdcE).approve(address(lancaCanonicalBridge), 1000 * 1e6);

        vm.expectRevert(
            abi.encodeWithSelector(RateLimiter.RateLimitExceeded.selector, 1000 * 1e6, 0)
        );
        LancaCanonicalBridge(address(lancaCanonicalBridge)).sendToken{value: messageFee}(
            1000 * 1e6,
            address(0),
            ConceroTypes.EvmDstChainData({receiver: lancaBridgeL1Mock, gasLimit: GAS_LIMIT})
        );
        vm.stopPrank();

        (uint128 availableVolume, uint128 maxAmount, , , bool isActive) = LancaCanonicalBridge(
            address(lancaCanonicalBridge)
        ).getOutboundRateInfo();
        assertEq(maxAmount, 0);
        assertFalse(isActive);
        assertEq(availableVolume, 0);
    }

    function test_outboundRateLimit_InvalidConfiguration() public {
        vm.expectRevert(
            abi.encodeWithSelector(RateLimiter.InvalidRateConfig.selector, 50e6, 100e6)
        );

        vm.prank(deployer);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setOutboundRateLimit(
            50e6, // maxAmount
            100e6 // refillSpeed > maxAmount
        );

        // But it should be allowed when maxAmount = 0 (disabled state)
        vm.prank(deployer);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setOutboundRateLimit(
            0, // maxAmount = 0 (disabled)
            100e6 // refillSpeed can be anything when disabled
        );

        (
            uint128 availableVolume,
            uint128 maxAmount,
            uint128 refillSpeed,
            ,
            bool isActive
        ) = LancaCanonicalBridge(address(lancaCanonicalBridge)).getOutboundRateInfo();
        assertEq(maxAmount, 0);
        assertEq(refillSpeed, 100e6);
        assertFalse(isActive);
        assertEq(availableVolume, 0);
    }

    function test_outboundRateLimit_PartialRefill() public {
        vm.prank(deployer);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setOutboundRateLimit(
            MAX_RATE_AMOUNT,
            REFILL_SPEED
        );

        // Consume most of the rate
        _performTransfer(900 * 1e6);

        (uint128 availableVolume, , , , ) = LancaCanonicalBridge(address(lancaCanonicalBridge))
            .getOutboundRateInfo();
        assertEq(availableVolume, 100 * 1e6);

        // Wait for partial refill (20 seconds = 200 USDC)
        vm.warp(block.timestamp + 20);

        // Should be able to transfer 300 USDC (100 + 200)
        _performTransfer(300 * 1e6);

        (availableVolume, , , , ) = LancaCanonicalBridge(address(lancaCanonicalBridge))
            .getOutboundRateInfo();
        assertEq(availableVolume, 0);
    }

    function test_outboundRateLimit_ReducingMaxAmountCapsAvailable() public {
        vm.prank(deployer);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setOutboundRateLimit(
            MAX_RATE_AMOUNT, // 1000 USDC
            REFILL_SPEED
        );

        // Consume some rate, leaving 800 USDC available
        _performTransfer(200 * 1e6);

        (uint128 availableBefore, , , , ) = LancaCanonicalBridge(address(lancaCanonicalBridge))
            .getOutboundRateInfo();
        assertEq(availableBefore, 800 * 1e6);

        // Reduce max amount to 500 USDC (less than current available)
        vm.prank(deployer);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setOutboundRateLimit(
            500e6, // 500 USDC (new limit)
            REFILL_SPEED
        );

        // Available should be capped at new maxAmount
        (uint128 availableAfter, uint128 maxAmount, , , ) = LancaCanonicalBridge(
            address(lancaCanonicalBridge)
        ).getOutboundRateInfo();
        assertEq(maxAmount, 500e6);
        assertEq(availableAfter, 500e6); // Capped at new limit, not 800

        // Should only be able to transfer up to the new limit
        _performTransfer(500 * 1e6);

        (uint128 finalAvailable, , , , ) = LancaCanonicalBridge(address(lancaCanonicalBridge))
            .getOutboundRateInfo();
        assertEq(finalAvailable, 0);
    }

    // --- Helper functions ---

    function _performTransfer(uint256 amount) internal {
        vm.startPrank(user);
        MockUSDCe(usdcE).approve(address(lancaCanonicalBridge), amount);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).sendToken{value: _getMessageFee()}(
            amount,
            address(0),
            ConceroTypes.EvmDstChainData({receiver: lancaBridgeL1Mock, gasLimit: GAS_LIMIT})
        );
        vm.stopPrank();
    }

    function _getMessageFee() internal view returns (uint256) {
        return
            LancaCanonicalBridge(address(lancaCanonicalBridge)).getMessageFee(
                SRC_CHAIN_SELECTOR,
                address(0),
                ConceroTypes.EvmDstChainData({receiver: lancaBridgeL1Mock, gasLimit: GAS_LIMIT})
            );
    }
}
