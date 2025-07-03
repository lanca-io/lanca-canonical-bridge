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

import {RateLimiter} from "contracts/common/RateLimiter.sol";

import {LCBridgeL1Test} from "./base/LCBridgeL1Test.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";

contract OutboundRateLimitsTest is LCBridgeL1Test {
    function setUp() public override {
        super.setUp();

        _addDefaultPool();
        _addDefaultLane();

        deal(address(usdc), user, 10_000 * 1e6); // 10K USDC
    }

    function test_setOutboundRateLimit_RevertsUnauthorized() public {
        vm.expectRevert(CommonErrors.Unauthorized.selector);
        lancaCanonicalBridgeL1.setOutboundRateLimit(
            DST_CHAIN_SELECTOR,
            PERIOD,
            MAX_AMOUNT_PER_PERIOD
        );
    }

    function test_setOutboundRateLimit_Success() public {
        vm.expectEmit(true, true, true, true);
        emit RateLimiter.RateLimitOutboundConfigSet(
            DST_CHAIN_SELECTOR,
            PERIOD,
            MAX_AMOUNT_PER_PERIOD
        );

        // Set rate limit
        vm.prank(deployer);
        lancaCanonicalBridgeL1.setOutboundRateLimit(
            DST_CHAIN_SELECTOR,
            PERIOD,
            MAX_AMOUNT_PER_PERIOD
        );

        (
            uint128 used,
            uint32 periodInfo,
            uint128 maxAmountInfo,
            uint32 lastReset,
            uint256 available
        ) = lancaCanonicalBridgeL1.getOutboundRateLimitInfo(DST_CHAIN_SELECTOR);

        assertEq(used, 0);
        assertEq(periodInfo, PERIOD);
        assertEq(maxAmountInfo, MAX_AMOUNT_PER_PERIOD);
        assertGt(lastReset, 0);
        assertEq(available, MAX_AMOUNT_PER_PERIOD);

        // Test that setting again resets used amount
        _performTransfer(100 * 1e6);

        vm.prank(deployer);
        lancaCanonicalBridgeL1.setOutboundRateLimit(
            DST_CHAIN_SELECTOR,
            PERIOD,
            MAX_AMOUNT_PER_PERIOD
        );

        (used, , , , available) = lancaCanonicalBridgeL1.getOutboundRateLimitInfo(
            DST_CHAIN_SELECTOR
        );
        assertEq(used, 0);
        assertEq(available, MAX_AMOUNT_PER_PERIOD);
    }

    function test_outboundRateLimit_TransferWithinLimit() public {
        vm.prank(deployer);
        lancaCanonicalBridgeL1.setOutboundRateLimit(
            DST_CHAIN_SELECTOR,
            PERIOD,
            MAX_AMOUNT_PER_PERIOD
        );

        _performTransfer(500 * 1e6); // 500 USDC

        (uint128 used, , , , uint256 available) = lancaCanonicalBridgeL1.getOutboundRateLimitInfo(
            DST_CHAIN_SELECTOR
        );
        assertEq(used, 500 * 1e6);
        assertEq(available, 500 * 1e6);
    }

    function test_outboundRateLimit_RevertsIfRateLimitExceeded() public {
        vm.prank(deployer);
        lancaCanonicalBridgeL1.setOutboundRateLimit(
            DST_CHAIN_SELECTOR,
            PERIOD,
            MAX_AMOUNT_PER_PERIOD
        );

        // First transfers accumulate
        _performTransfer(300 * 1e6); // 300 USDC
        _performTransfer(400 * 1e6); // 400 USDC

        (uint128 used, , , , uint256 available) = lancaCanonicalBridgeL1.getOutboundRateLimitInfo(
            DST_CHAIN_SELECTOR
        );
        assertEq(used, 700 * 1e6); // 700 USDC
        assertEq(available, 300 * 1e6); // 300 USDC

        // Next transfer should fail
        uint256 messageFee = _getMessageFee();
        vm.startPrank(user);
        MockUSDC(usdc).approve(address(lancaCanonicalBridgePool), 400 * 1e6);

        vm.expectRevert(
            abi.encodeWithSelector(RateLimiter.RateLimitExceeded.selector, 400 * 1e6, 300 * 1e6)
        );
        lancaCanonicalBridgeL1.sendToken{value: messageFee}(
            400 * 1e6,
            DST_CHAIN_SELECTOR,
            address(0),
            ConceroTypes.EvmDstChainData({receiver: lancaBridgeMock, gasLimit: GAS_LIMIT}),
            lcbCallData
        );
        vm.stopPrank();
    }

    function test_outboundRateLimit_ResetsAfterPeriod() public {
        vm.prank(deployer);
        lancaCanonicalBridgeL1.setOutboundRateLimit(DST_CHAIN_SELECTOR, 60, MAX_AMOUNT_PER_PERIOD);

        _performTransfer(MAX_AMOUNT_PER_PERIOD);

        (uint128 used, , , , uint256 available) = lancaCanonicalBridgeL1.getOutboundRateLimitInfo(
            DST_CHAIN_SELECTOR
        );
        assertEq(used, MAX_AMOUNT_PER_PERIOD);
        assertEq(available, 0);

        vm.warp(block.timestamp + 61);

        (, , , , available) = lancaCanonicalBridgeL1.getOutboundRateLimitInfo(DST_CHAIN_SELECTOR);
        assertEq(available, MAX_AMOUNT_PER_PERIOD);

        _performTransfer(MAX_AMOUNT_PER_PERIOD);
    }

    function test_outboundRateLimit_DisabledWithZeroPeriod() public {
        vm.prank(deployer);
        lancaCanonicalBridgeL1.setOutboundRateLimit(DST_CHAIN_SELECTOR, 0, MAX_AMOUNT_PER_PERIOD);

        _performTransfer(5000 * 1e6);
    }

    // --- Helper functions ---

    function _performTransfer(uint256 amount) internal {
        vm.startPrank(user);
        MockUSDC(usdc).approve(address(lancaCanonicalBridgePool), amount);
        lancaCanonicalBridgeL1.sendToken{value: _getMessageFee()}(
            amount,
            DST_CHAIN_SELECTOR,
            address(0),
            ConceroTypes.EvmDstChainData({receiver: lancaBridgeMock, gasLimit: GAS_LIMIT}),
            lcbCallData
        );
        vm.stopPrank();
    }

    function _getMessageFee() internal view returns (uint256) {
        return
            lancaCanonicalBridgeL1.getMessageFee(
                DST_CHAIN_SELECTOR,
                address(0),
                ConceroTypes.EvmDstChainData({receiver: lancaBridgeMock, gasLimit: GAS_LIMIT})
            );
    }
}
