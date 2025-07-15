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
import {LancaCanonicalBridge} from "contracts/LancaCanonicalBridge/LancaCanonicalBridge.sol";

import {LCBridgeTest} from "./base/LCBridgeTest.sol";
import {MockUSDCe} from "../mocks/MockUSDCe.sol";

contract OutboundFlowLimitsTest is LCBridgeTest {
    function setUp() public override {
        super.setUp();
        deal(address(usdcE), user, 10_000 * 1e6); // 10K USDC
    }

    function test_setOutboundFlowLimit_RevertsUnauthorized() public {
        vm.expectRevert(CommonErrors.Unauthorized.selector);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setOutboundFlowLimit(
            MAX_FLOW_AMOUNT,
            REFILL_SPEED
        );
    }

    function test_setOutboundFlowLimit_Success() public {
        vm.expectEmit(true, true, true, true);
        emit FlowLimiter.FlowLimitSet(SRC_CHAIN_SELECTOR, true, MAX_FLOW_AMOUNT, REFILL_SPEED);

        vm.prank(deployer);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setOutboundFlowLimit(
            MAX_FLOW_AMOUNT,
            REFILL_SPEED
        );

        (
            uint128 availableVolume,
            uint128 maxAmount,
            uint128 refillSpeed,
            uint32 lastUpdate,
            bool isActive
        ) = LancaCanonicalBridge(address(lancaCanonicalBridge)).getOutboundFlowInfo();

        assertEq(availableVolume, MAX_FLOW_AMOUNT);
        assertEq(maxAmount, MAX_FLOW_AMOUNT);
        assertEq(refillSpeed, REFILL_SPEED);
        assertGt(lastUpdate, 0);
        assertTrue(isActive);
    }

    function test_setOutboundFlowLimit_PreservesStateOnConfigurationUpdate() public {
        vm.prank(deployer);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setOutboundFlowLimit(
            MAX_FLOW_AMOUNT,
            REFILL_SPEED
        );

        // Consume some flow
        _performTransfer(100 * 1e6);

        (uint128 availableBefore, , , , ) = LancaCanonicalBridge(address(lancaCanonicalBridge))
            .getOutboundFlowInfo();
        assertEq(availableBefore, MAX_FLOW_AMOUNT - 100 * 1e6);

        // Update configuration
        vm.prank(deployer);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setOutboundFlowLimit(
            MAX_FLOW_AMOUNT,
            REFILL_SPEED
        );

        // State should be preserved
        (uint128 availableAfter, , , , ) = LancaCanonicalBridge(address(lancaCanonicalBridge))
            .getOutboundFlowInfo();
        assertEq(availableAfter, MAX_FLOW_AMOUNT - 100 * 1e6);
    }

    function test_outboundFlowLimit_TransferWithinLimit() public {
        vm.prank(deployer);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setOutboundFlowLimit(
            MAX_FLOW_AMOUNT,
            REFILL_SPEED
        );

        _performTransfer(500 * 1e6); // 500 USDC

        (uint128 availableVolume, , , , ) = LancaCanonicalBridge(address(lancaCanonicalBridge))
            .getOutboundFlowInfo();
        assertEq(availableVolume, 500 * 1e6);
    }

    function test_outboundFlowLimit_RevertsIfFlowExceeded() public {
        vm.prank(deployer);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setOutboundFlowLimit(
            MAX_FLOW_AMOUNT,
            REFILL_SPEED
        );

        _performTransfer(300 * 1e6); // 300 USDC
        _performTransfer(400 * 1e6); // 400 USDC

        (uint128 availableVolume, , , , ) = LancaCanonicalBridge(address(lancaCanonicalBridge))
            .getOutboundFlowInfo();
        assertEq(availableVolume, 300 * 1e6); // 300 USDC left

        // Next transfer should fail
        uint256 messageFee = _getMessageFee();
        vm.startPrank(user);
        MockUSDCe(usdcE).approve(address(lancaCanonicalBridge), 400 * 1e6);

        vm.expectRevert(
            abi.encodeWithSelector(FlowLimiter.FlowLimitExceeded.selector, 400 * 1e6, 300 * 1e6)
        );
        LancaCanonicalBridge(address(lancaCanonicalBridge)).sendToken{value: messageFee}(
            400 * 1e6,
            address(0),
            ConceroTypes.EvmDstChainData({receiver: lancaBridgeL1Mock, gasLimit: GAS_LIMIT})
        );
        vm.stopPrank();
    }

    function test_outboundFlowLimit_RefillOverTime() public {
        vm.prank(deployer);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setOutboundFlowLimit(
            MAX_FLOW_AMOUNT,
            REFILL_SPEED
        );

        // Consume all available flow
        _performTransfer(MAX_FLOW_AMOUNT);

        (uint128 availableVolume, , , , ) = LancaCanonicalBridge(address(lancaCanonicalBridge))
            .getOutboundFlowInfo();
        assertEq(availableVolume, 0);

        // Wait for 50 seconds -> should refill 500 USDC
        vm.warp(block.timestamp + 50);

        // Should now be able to transfer 500 USDC
        _performTransfer(500 * 1e6);

        (availableVolume, , , , ) = LancaCanonicalBridge(address(lancaCanonicalBridge))
            .getOutboundFlowInfo();
        assertEq(availableVolume, 0);
    }

    function test_outboundFlowLimit_MaxAmountCapping() public {
        vm.prank(deployer);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setOutboundFlowLimit(
            MAX_FLOW_AMOUNT,
            REFILL_SPEED
        );

        // Consume half the flow
        _performTransfer(500 * 1e6);

        // Wait for a very long time (should cap at maxAmount)
        vm.warp(block.timestamp + 1000);

        (uint128 availableVolume, , , , ) = LancaCanonicalBridge(address(lancaCanonicalBridge))
            .getOutboundFlowInfo();
        assertEq(availableVolume, MAX_FLOW_AMOUNT);
    }

    function test_outboundFlowLimit_DisabledWithZeroMaxAmount() public {
        vm.prank(deployer);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setOutboundFlowLimit(0, REFILL_SPEED);

        // Transfers should be blocked when maxAmount = 0 (soft pause)
        uint256 messageFee = _getMessageFee();
        vm.startPrank(user);
        MockUSDCe(usdcE).approve(address(lancaCanonicalBridge), 1000 * 1e6);

        vm.expectRevert(
            abi.encodeWithSelector(FlowLimiter.FlowLimitExceeded.selector, 1000 * 1e6, 0)
        );
        LancaCanonicalBridge(address(lancaCanonicalBridge)).sendToken{value: messageFee}(
            1000 * 1e6,
            address(0),
            ConceroTypes.EvmDstChainData({receiver: lancaBridgeL1Mock, gasLimit: GAS_LIMIT})
        );
        vm.stopPrank();

        (uint128 availableVolume, uint128 maxAmount, , , bool isActive) = LancaCanonicalBridge(
            address(lancaCanonicalBridge)
        ).getOutboundFlowInfo();
        assertEq(maxAmount, 0);
        assertFalse(isActive);
        assertEq(availableVolume, 0);
    }

    function test_outboundFlowLimit_InvalidConfiguration() public {
        vm.expectRevert(
            abi.encodeWithSelector(FlowLimiter.InvalidFlowConfig.selector, 50e6, 100e6)
        );

        vm.prank(deployer);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setOutboundFlowLimit(
            50e6, // maxAmount
            100e6 // refillSpeed > maxAmount
        );

        // But it should be allowed when maxAmount = 0 (disabled state)
        vm.prank(deployer);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setOutboundFlowLimit(
            0, // maxAmount = 0 (disabled)
            100e6 // refillSpeed can be anything when disabled
        );

        (
            uint128 availableVolume,
            uint128 maxAmount,
            uint128 refillSpeed,
            ,
            bool isActive
        ) = LancaCanonicalBridge(address(lancaCanonicalBridge)).getOutboundFlowInfo();
        assertEq(maxAmount, 0);
        assertEq(refillSpeed, 100e6);
        assertFalse(isActive);
        assertEq(availableVolume, 0);
    }

    function test_outboundFlowLimit_PartialRefill() public {
        vm.prank(deployer);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setOutboundFlowLimit(
            MAX_FLOW_AMOUNT,
            REFILL_SPEED
        );

        // Consume most of the flow
        _performTransfer(900 * 1e6);

        (uint128 availableVolume, , , , ) = LancaCanonicalBridge(address(lancaCanonicalBridge))
            .getOutboundFlowInfo();
        assertEq(availableVolume, 100 * 1e6);

        // Wait for partial refill (20 seconds = 200 USDC)
        vm.warp(block.timestamp + 20);

        // Should be able to transfer 300 USDC (100 + 200)
        _performTransfer(300 * 1e6);

        (availableVolume, , , , ) = LancaCanonicalBridge(address(lancaCanonicalBridge))
            .getOutboundFlowInfo();
        assertEq(availableVolume, 0);
    }

    function test_outboundFlowLimit_ReducingMaxAmountCapsAvailable() public {
        vm.prank(deployer);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setOutboundFlowLimit(
            MAX_FLOW_AMOUNT, // 1000 USDC
            REFILL_SPEED
        );

        // Consume some flow, leaving 800 USDC available
        _performTransfer(200 * 1e6);

        (uint128 availableBefore, , , , ) = LancaCanonicalBridge(address(lancaCanonicalBridge))
            .getOutboundFlowInfo();
        assertEq(availableBefore, 800 * 1e6);

        // Reduce max amount to 500 USDC (less than current available)
        vm.prank(deployer);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setOutboundFlowLimit(
            500e6, // 500 USDC (new limit)
            REFILL_SPEED
        );

        // Available should be capped at new maxAmount
        (uint128 availableAfter, uint128 maxAmount, , , ) = LancaCanonicalBridge(
            address(lancaCanonicalBridge)
        ).getOutboundFlowInfo();
        assertEq(maxAmount, 500e6);
        assertEq(availableAfter, 500e6); // Capped at new limit, not 800

        // Should only be able to transfer up to the new limit
        _performTransfer(500 * 1e6);

        (uint128 finalAvailable, , , , ) = LancaCanonicalBridge(address(lancaCanonicalBridge))
            .getOutboundFlowInfo();
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
