// SPDX-License-Identifier: UNLICENSED
/* solhint-disable func-name-mixedcase */
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {CommonErrors} from "@concero/messaging-contracts-v2/contracts/common/CommonErrors.sol";

import {RateLimiter} from "contracts/LancaCanonicalBridge/RateLimiter.sol";
import {LancaCanonicalBridgeBase} from "contracts/LancaCanonicalBridge/LancaCanonicalBridgeBase.sol";
import {LancaCanonicalBridge} from "contracts/LancaCanonicalBridge/LancaCanonicalBridge.sol";

import {LCBridgeTest} from "./base/LCBridgeTest.sol";
import {MockUSDCe} from "../mocks/MockUSDCe.sol";

contract InboundRateLimitsTest is LCBridgeTest {
    function setUp() public override {
        super.setUp();

        // Add funds to bridge contract for minting
        MockUSDCe(usdcE).setMinter(address(lancaCanonicalBridge));
    }

    function test_setInboundRateLimit_RevertsUnauthorized() public {
        vm.expectRevert(CommonErrors.Unauthorized.selector);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setInboundRateLimit(
            PERIOD,
            MAX_AMOUNT_PER_PERIOD
        );
    }

    function test_setInboundRateLimit_Success() public {
        vm.expectEmit(true, true, true, true);
        emit RateLimiter.RateLimitInboundConfigSet(
            SRC_CHAIN_SELECTOR,
            PERIOD,
            MAX_AMOUNT_PER_PERIOD
        );

        vm.prank(deployer);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setInboundRateLimit(
            PERIOD,
            MAX_AMOUNT_PER_PERIOD
        );

        (
            uint128 used,
            uint32 periodInfo,
            uint128 maxAmountInfo,
            uint32 lastReset,
            uint256 available
        ) = LancaCanonicalBridge(address(lancaCanonicalBridge)).getInboundRateLimitInfo();

        assertEq(used, 0);
        assertEq(periodInfo, PERIOD);
        assertEq(maxAmountInfo, MAX_AMOUNT_PER_PERIOD);
        assertGt(lastReset, 0);
        assertEq(available, MAX_AMOUNT_PER_PERIOD);

        _performReceive(100 * 1e6);

        vm.prank(deployer);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setInboundRateLimit(
            PERIOD,
            MAX_AMOUNT_PER_PERIOD
        );

        (used, , , , available) = LancaCanonicalBridge(address(lancaCanonicalBridge))
            .getInboundRateLimitInfo();
        assertEq(used, 0);
        assertEq(available, MAX_AMOUNT_PER_PERIOD);
    }

    function test_inboundRateLimit_ReceiveWithinLimit() public {
        vm.prank(deployer);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setInboundRateLimit(
            PERIOD,
            MAX_AMOUNT_PER_PERIOD
        );

        _performReceive(500 * 1e6); // 500 USDC

        (uint128 used, , , , uint256 available) = LancaCanonicalBridge(
            address(lancaCanonicalBridge)
        ).getInboundRateLimitInfo();
        assertEq(used, 500 * 1e6);
        assertEq(available, 500 * 1e6);
    }

    function test_inboundRateLimit_RevertsIfRateLimitExceeded() public {
        vm.prank(deployer);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setInboundRateLimit(
            PERIOD,
            MAX_AMOUNT_PER_PERIOD
        );

        // First receives accumulate
        _performReceive(300 * 1e6); // 300 USDC
        _performReceive(400 * 1e6); // 400 USDC

        (uint128 used, , , , uint256 available) = LancaCanonicalBridge(
            address(lancaCanonicalBridge)
        ).getInboundRateLimitInfo();
        assertEq(used, 700 * 1e6); // 700 USDC
        assertEq(available, 300 * 1e6); // 300 USDC

        // Next receive should fail
        vm.expectRevert(
            abi.encodeWithSelector(RateLimiter.RateLimitExceeded.selector, 400 * 1e6, 300 * 1e6)
        );
        _performReceive(400 * 1e6);
    }

    function test_inboundRateLimit_ResetsAfterPeriod() public {
        vm.prank(deployer);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setInboundRateLimit(
            60,
            MAX_AMOUNT_PER_PERIOD
        );

        _performReceive(MAX_AMOUNT_PER_PERIOD);

        (uint128 used, , , , uint256 available) = LancaCanonicalBridge(
            address(lancaCanonicalBridge)
        ).getInboundRateLimitInfo();
        assertEq(used, MAX_AMOUNT_PER_PERIOD);
        assertEq(available, 0);

        vm.warp(block.timestamp + 61);

        (, , , , available) = LancaCanonicalBridge(address(lancaCanonicalBridge))
            .getInboundRateLimitInfo();
        assertEq(available, MAX_AMOUNT_PER_PERIOD);

        _performReceive(MAX_AMOUNT_PER_PERIOD);
    }

    function test_inboundRateLimit_DisabledWithZeroPeriod() public {
        vm.prank(deployer);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setInboundRateLimit(
            0,
            MAX_AMOUNT_PER_PERIOD
        );

        _performReceive(5000 * 1e6);
    }

    // --- Helper functions ---

    function _performReceive(uint256 amount) internal {
        bytes memory message = abi.encode(user, amount);

        vm.prank(conceroRouter);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).conceroReceive(
            DEFAULT_MESSAGE_ID,
            SRC_CHAIN_SELECTOR,
            abi.encode(lancaBridgeL1Mock),
            message
        );
    }
}
