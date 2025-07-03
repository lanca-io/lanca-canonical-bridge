// SPDX-License-Identifier: UNLICENSED
/* solhint-disable func-name-mixedcase */
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {CommonErrors} from "@concero/messaging-contracts-v2/contracts/common/CommonErrors.sol";

import {FlowLimiter} from "contracts/LancaCanonicalBridge/FlowLimiter.sol";
import {LancaCanonicalBridgeBase} from "contracts/LancaCanonicalBridge/LancaCanonicalBridgeBase.sol";
import {LancaCanonicalBridge} from "contracts/LancaCanonicalBridge/LancaCanonicalBridge.sol";

import {LCBridgeTest} from "./base/LCBridgeTest.sol";
import {MockUSDCe} from "../mocks/MockUSDCe.sol";

contract InboundFlowLimitsTest is LCBridgeTest {
    function setUp() public override {
        super.setUp();
        // Add funds to bridge contract for minting
        MockUSDCe(usdcE).setMinter(address(lancaCanonicalBridge));
    }

    function test_setInboundFlowLimit_RevertsUnauthorized() public {
        vm.expectRevert(CommonErrors.Unauthorized.selector);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setInboundFlowLimit(
            MAX_FLOW_AMOUNT,
            REFILL_SPEED
        );
    }

    function test_setInboundFlowLimit_Success() public {
        vm.expectEmit(true, true, true, true);
        emit FlowLimiter.FlowLimitSet(
            SRC_CHAIN_SELECTOR,
            false,
            MAX_FLOW_AMOUNT,
            REFILL_SPEED
        );

        vm.prank(deployer);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setInboundFlowLimit(
            MAX_FLOW_AMOUNT,
            REFILL_SPEED
        );

        (
            uint128 available,
            uint128 maxAmount,
            uint128 refillSpeed,
            uint32 lastUpdate,
            bool isActive
        ) = LancaCanonicalBridge(address(lancaCanonicalBridge)).getInboundFlowInfo();

        assertEq(available, MAX_FLOW_AMOUNT);
        assertEq(maxAmount, MAX_FLOW_AMOUNT);
        assertEq(refillSpeed, REFILL_SPEED);
        assertGt(lastUpdate, 0);
        assertTrue(isActive);
    }

    function test_setInboundFlowLimit_PreservesStateOnConfigurationUpdate() public {
        vm.prank(deployer);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setInboundFlowLimit(
            MAX_FLOW_AMOUNT,
            REFILL_SPEED
        );

        // Consume some flow
        _performReceive(100 * 1e6);

        (uint128 availableBefore, , , , ) = LancaCanonicalBridge(address(lancaCanonicalBridge))
            .getInboundFlowInfo();
        assertEq(availableBefore, MAX_FLOW_AMOUNT - 100 * 1e6);

        // Update configuration
        vm.prank(deployer);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setInboundFlowLimit(
            MAX_FLOW_AMOUNT,
            REFILL_SPEED
        );

        // State should be preserved
        (uint128 availableAfter, , , , ) = LancaCanonicalBridge(address(lancaCanonicalBridge))
            .getInboundFlowInfo();
        assertEq(availableAfter, MAX_FLOW_AMOUNT - 100 * 1e6);
    }

    function test_inboundFlowLimit_ReceiveWithinLimit() public {
        vm.prank(deployer);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setInboundFlowLimit(
            MAX_FLOW_AMOUNT,
            REFILL_SPEED
        );

        _performReceive(500 * 1e6); // 500 USDC

        (uint128 available, , , , ) = LancaCanonicalBridge(address(lancaCanonicalBridge))
            .getInboundFlowInfo();
        assertEq(available, 500 * 1e6);
    }

    function test_inboundFlowLimit_RevertsIfFlowExceeded() public {
        vm.prank(deployer);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setInboundFlowLimit(
            MAX_FLOW_AMOUNT,
            REFILL_SPEED
        );

        // First receives accumulate
        _performReceive(300 * 1e6); // 300 USDC
        _performReceive(400 * 1e6); // 400 USDC

        (uint128 available, , , , ) = LancaCanonicalBridge(address(lancaCanonicalBridge))
            .getInboundFlowInfo();
        assertEq(available, 300 * 1e6); // 300 USDC left

        // Next receive should fail
        bytes memory message = abi.encode(user, 400 * 1e6);

        vm.expectRevert(
            abi.encodeWithSelector(FlowLimiter.FlowLimitExceeded.selector, 400 * 1e6, 300 * 1e6)
        );

        vm.prank(conceroRouter);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).conceroReceive(
            DEFAULT_MESSAGE_ID,
            SRC_CHAIN_SELECTOR,
            abi.encode(lancaBridgeL1Mock),
            message
        );
    }

    function test_inboundFlowLimit_RefillOverTime() public {
        vm.prank(deployer);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setInboundFlowLimit(
            MAX_FLOW_AMOUNT,
            REFILL_SPEED
        );

        // Consume all available flow
        _performReceive(MAX_FLOW_AMOUNT);

        (uint128 available, , , , ) = LancaCanonicalBridge(address(lancaCanonicalBridge))
            .getInboundFlowInfo();
        assertEq(available, 0);

        // Wait for 50 seconds -> should refill 500 USDC
        vm.warp(block.timestamp + 50);

        // Should now be able to receive 500 USDC
        _performReceive(500 * 1e6);

        (available, , , , ) = LancaCanonicalBridge(address(lancaCanonicalBridge))
            .getInboundFlowInfo();
        assertEq(available, 0);
    }

    function test_inboundFlowLimit_MaxAmountCapping() public {
        vm.prank(deployer);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setInboundFlowLimit(
            MAX_FLOW_AMOUNT,
            REFILL_SPEED
        );

        // Consume half the flow
        _performReceive(500 * 1e6);

        // Wait for a very long time (should cap at maxAmount)
        vm.warp(block.timestamp + 1000);

        (uint128 available, , , , ) = LancaCanonicalBridge(address(lancaCanonicalBridge))
            .getInboundFlowInfo();
        assertEq(available, MAX_FLOW_AMOUNT);
    }

    function test_inboundFlowLimit_DisabledWithZeroMaxAmount() public {
        vm.prank(deployer);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setInboundFlowLimit(
            0,
            REFILL_SPEED
        );

        // Should be able to receive unlimited amounts
        _performReceive(5000 * 1e6);

        (uint128 available, uint128 maxAmount, , , bool isActive) = LancaCanonicalBridge(
            address(lancaCanonicalBridge)
        ).getInboundFlowInfo();
        assertEq(maxAmount, 0);
        assertFalse(isActive);
        assertEq(available, 0);
    }

    function test_inboundFlowLimit_InvalidConfiguration() public {
        vm.expectRevert(
            abi.encodeWithSelector(FlowLimiter.InvalidFlowConfig.selector, 50e6, 100e6)
        );

        vm.prank(deployer);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setInboundFlowLimit(
            50e6, // maxAmount
            100e6 // refillSpeed > maxAmount
        );
    }

    function test_inboundFlowLimit_PartialRefill() public {
        vm.prank(deployer);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setInboundFlowLimit(
            MAX_FLOW_AMOUNT,
            REFILL_SPEED
        );

        // Consume most of the flow
        _performReceive(900 * 1e6);

        (uint128 available, , , , ) = LancaCanonicalBridge(address(lancaCanonicalBridge))
            .getInboundFlowInfo();
        assertEq(available, 100 * 1e6);

        // Wait for partial refill (20 seconds = 200 USDC)
        vm.warp(block.timestamp + 20);

        // Should be able to receive 300 USDC (100 + 200)
        _performReceive(300 * 1e6);

        (available, , , , ) = LancaCanonicalBridge(address(lancaCanonicalBridge))
            .getInboundFlowInfo();
        assertEq(available, 0);
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
