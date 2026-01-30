// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {IConceroRouter} from "@concero/v2-contracts/contracts/interfaces/IConceroRouter.sol";
import {MessageCodec} from "@concero/v2-contracts/contracts/common/libraries/MessageCodec.sol";
import {BridgeCodec} from "contracts/common/libraries/BridgeCodec.sol";
import {LancaCanonicalBridgeL1} from "contracts/LancaCanonicalBridge/LancaCanonicalBridgeL1.sol";
import {LancaCanonicalBridge} from "contracts/LancaCanonicalBridge/LancaCanonicalBridge.sol";
import {LancaCanonicalBridgePool} from "contracts/LancaCanonicalBridgePool/LancaCanonicalBridgePool.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";
import {MockUSDCe} from "../mocks/MockUSDCe.sol";
import {LCBTest} from "../helpers/LCBTest.sol";

contract BackfillMechanismTest is LCBTest {
    using MessageCodec for IConceroRouter.MessageRequest;
    using BridgeCodec for bytes32;
    using BridgeCodec for address;

    uint24 constant L1_CHAIN_SELECTOR = 1; // Ethereum
    uint24 constant L2_CHAIN_SELECTOR = 2; // Arbitrum (say)

    LancaCanonicalBridgeL1 public bridgeL1; // Ethereum bridge
    LancaCanonicalBridge public bridgeL2; // Arbitrum bridge
    LancaCanonicalBridgePool public pool;

    MockUSDC public usdc; // Native USDC on L1
    MockUSDCe public usdce; // USDC.e on L2

    uint256 constant USER_AMOUNT = 1000e6; // 1000 USDC
    uint128 constant RATE_LIMIT_MAX_2 = 5000e6; // 5000 USDC max capacity
    uint128 constant REFILL_SPEED_2 = 10e6; // 10 USDC per second

    function setUp() public {
        // Deploy tokens
        usdc = new MockUSDC("USD Coin", "USDC", 6);
        usdce = new MockUSDCe("USD Coin.e", "USDC.e", 6);

        // Deploy L1 bridge
        vm.prank(s_deployer);
        bridgeL1 = new LancaCanonicalBridgeL1(s_conceroRouter, address(usdc));
        bridgeL1.initialize(s_deployer);

        // Deploy L2 bridge
        vm.prank(s_deployer);
        bridgeL2 = new LancaCanonicalBridge(
            L1_CHAIN_SELECTOR,
            s_conceroRouter,
            address(usdce),
            address(bridgeL1)
        );
        bridgeL2.initialize(s_deployer);

        // Deploy pool for L2 chain on L1
        pool = new LancaCanonicalBridgePool(address(usdc), address(bridgeL1), L2_CHAIN_SELECTOR);

        // Setup L1 bridge
        _setupL1Bridge();

        // Setup L2 bridge
        _setupL2Bridge();

        // Fund user
        usdc.mint(s_user, USER_AMOUNT);
        usdce.mintTo(s_user, USER_AMOUNT);
        usdc.mint(address(pool), 100_000e6); // Fund pool for withdrawals
        vm.deal(s_user, 10 ether);
    }

    function _setupL1Bridge() internal {
        _setValidatorLibs(address(bridgeL1));
        _setRelayerLib(address(bridgeL1));

        vm.startPrank(s_deployer);

        // Add pool for L2
        uint24[] memory dstChains = new uint24[](1);
        dstChains[0] = L2_CHAIN_SELECTOR;
        address[] memory pools = new address[](1);
        pools[0] = address(pool);
        bridgeL1.addPools(dstChains, pools);

        // Add L2 bridge address
        bytes32[] memory dstBridges = new bytes32[](1);
        dstBridges[0] = address(bridgeL2).toBytes32();
        bridgeL1.addDstBridges(dstChains, dstBridges);

        // Set rate limits for L1 -> L2 and L2 -> L1
        bridgeL1.setRateLimit(L2_CHAIN_SELECTOR, RATE_LIMIT_MAX_2, REFILL_SPEED_2, true); // outbound to L2
        bridgeL1.setRateLimit(L2_CHAIN_SELECTOR, RATE_LIMIT_MAX_2, REFILL_SPEED_2, false); // inbound from L2

        vm.stopPrank();
    }

    function _setupL2Bridge() internal {
        _setValidatorLibs(address(bridgeL2));
        _setRelayerLib(address(bridgeL2));

        vm.startPrank(s_deployer);

        // Set minter for USDC.e
        usdce.setMinter(address(bridgeL2));

        // Set rate limits for L2 -> L1 and L1 -> L2
        bridgeL2.setRateLimit(L1_CHAIN_SELECTOR, RATE_LIMIT_MAX_2, REFILL_SPEED_2, true); // outbound to L1
        bridgeL2.setRateLimit(L1_CHAIN_SELECTOR, RATE_LIMIT_MAX_2, REFILL_SPEED_2, false); // inbound from L1

        vm.stopPrank();
    }

    /**
     * @notice This test demonstrates backfill mechanism in rate limits.
     */
    function test_BackfillMechanism_ShouldBackfillOppositeRateLimit() public {
        // Verify initial state: both chains have full capacity
        (uint128 l1OutboundBefore, , , , ) = bridgeL1.getRateInfo(L2_CHAIN_SELECTOR, true);
        (uint128 l1InboundBefore, , , , ) = bridgeL1.getRateInfo(L2_CHAIN_SELECTOR, false);
        (uint128 l2OutboundBefore, , , , ) = bridgeL2.getRateInfo(L1_CHAIN_SELECTOR, true);
        (uint128 l2InboundBefore, , , , ) = bridgeL2.getRateInfo(L1_CHAIN_SELECTOR, false);

        assertEq(l1OutboundBefore, RATE_LIMIT_MAX_2);
        assertEq(l1InboundBefore, RATE_LIMIT_MAX_2);
        assertEq(l2OutboundBefore, RATE_LIMIT_MAX_2);
        assertEq(l2InboundBefore, RATE_LIMIT_MAX_2);

        // User sends from L1 to L2
        vm.startPrank(s_user);
        usdc.approve(address(pool), USER_AMOUNT);

        uint256 l1Fee = _getL1MessageFee();
        bridgeL1.sendToken{value: l1Fee}(
            USER_AMOUNT,
            L2_CHAIN_SELECTOR,
            MessageCodec.encodeEvmDstChainData(s_user, 0),
            ""
        );
        vm.stopPrank();

        // check rate limits after each step
        (uint128 l1OutboundAfterSend, , , , ) = bridgeL1.getRateInfo(L2_CHAIN_SELECTOR, true);
        assertEq(l1OutboundAfterSend, RATE_LIMIT_MAX_2 - USER_AMOUNT);

        // Message received on L2
        _simulateL2Receive(s_user, USER_AMOUNT);

        (uint128 l2InboundAfterReceive, , , , ) = bridgeL2.getRateInfo(L1_CHAIN_SELECTOR, false);
        assertEq(l2InboundAfterReceive, RATE_LIMIT_MAX_2 - USER_AMOUNT);

        // User sends same tokens back from L2 to L1
        vm.startPrank(s_user);
        usdce.approve(address(bridgeL2), USER_AMOUNT);
        uint256 l2Fee = _getL2MessageFee();
        bridgeL2.sendToken{value: l2Fee}(
            USER_AMOUNT,
            MessageCodec.encodeEvmDstChainData(s_user, 0),
            ""
        );
        vm.stopPrank();

        (uint128 l2OutboundAfterSend, , , , ) = bridgeL2.getRateInfo(L1_CHAIN_SELECTOR, true);
        assertEq(l2OutboundAfterSend, RATE_LIMIT_MAX_2 - USER_AMOUNT);

        // Message received back on L1
        _simulateL1Receive(s_user, USER_AMOUNT);

        (uint128 l1InboundAfterReceive, , , , ) = bridgeL1.getRateInfo(L2_CHAIN_SELECTOR, false);
        assertEq(l1InboundAfterReceive, RATE_LIMIT_MAX_2 - USER_AMOUNT);

        // Continue sending tokens for 4 more round trips to severely deplete capacity
        for (uint i = 0; i < 4; i++) {
            // L1 -> L2
            vm.startPrank(s_user);
            usdc.approve(address(pool), USER_AMOUNT);
            bridgeL1.sendToken{value: l1Fee}(
                USER_AMOUNT,
                L2_CHAIN_SELECTOR,
                MessageCodec.encodeEvmDstChainData(s_user, 0),
                ""
            );
            vm.stopPrank();
            _simulateL2Receive(s_user, USER_AMOUNT);

            // L2 -> L1
            vm.startPrank(s_user);
            usdce.approve(address(bridgeL2), USER_AMOUNT);
            bridgeL2.sendToken{value: l2Fee}(
                USER_AMOUNT,
                MessageCodec.encodeEvmDstChainData(s_user, 0),
                ""
            );
            vm.stopPrank();
            _simulateL1Receive(s_user, USER_AMOUNT);
        }

        (uint128 l1OutboundFinal, , , , ) = bridgeL1.getRateInfo(L2_CHAIN_SELECTOR, true);
        (uint128 l1InboundFinal, , , , ) = bridgeL1.getRateInfo(L2_CHAIN_SELECTOR, false);
        (uint128 l2OutboundFinal, , , , ) = bridgeL2.getRateInfo(L1_CHAIN_SELECTOR, true);
        (uint128 l2InboundFinal, , , , ) = bridgeL2.getRateInfo(L1_CHAIN_SELECTOR, false);

        assertEq(l1OutboundFinal, RATE_LIMIT_MAX_2);
        assertEq(l1InboundFinal, RATE_LIMIT_MAX_2 - USER_AMOUNT);
        assertEq(l2OutboundFinal, RATE_LIMIT_MAX_2 - USER_AMOUNT);
        assertEq(l2InboundFinal, RATE_LIMIT_MAX_2);
    }

    /**
     * @notice Test that backfill mechanism doesn't overflow maxAmount in opposite rate
     * @dev When opposite rate already has full or near-full availableVolume,
     *      backfill should cap at maxAmount, not exceed it
     */
    function test_BackfillMechanism_ShouldNotOverflowMaxAmount() public {
        // Initial state: all buckets have full capacity (5000 USDC each)
        (uint128 l2InboundBefore, , , , ) = bridgeL2.getRateInfo(L1_CHAIN_SELECTOR, false);
        assertEq(l2InboundBefore, RATE_LIMIT_MAX_2, "L2 inbound should start at max");

        // User sends from L2 to L1
        // This consumes L2 outbound rate and should backfill L2 inbound rate
        // But L2 inbound is already at max, so it should stay at max (not overflow)
        vm.startPrank(s_user);
        usdce.approve(address(bridgeL2), USER_AMOUNT);
        uint256 l2Fee = _getL2MessageFee();
        bridgeL2.sendToken{value: l2Fee}(
            USER_AMOUNT,
            MessageCodec.encodeEvmDstChainData(s_user, 0),
            ""
        );
        vm.stopPrank();

        // After send: L2 outbound consumed, but L2 inbound should NOT exceed maxAmount
        (uint128 l2OutboundAfter, , , , ) = bridgeL2.getRateInfo(L1_CHAIN_SELECTOR, true);
        (uint128 l2InboundAfter, , , , ) = bridgeL2.getRateInfo(L1_CHAIN_SELECTOR, false);

        assertEq(
            l2OutboundAfter,
            RATE_LIMIT_MAX_2 - USER_AMOUNT,
            "L2 outbound should decrease by amount"
        );
        assertEq(l2InboundAfter, RATE_LIMIT_MAX_2, "L2 inbound should stay at maxAmount");
    }

    function _simulateL2Receive(address recipient, uint256 amount) internal {
        IConceroRouter.MessageRequest memory messageRequest = _buildMessageRequest(
            BridgeCodec.encodeBridgeData(recipient, recipient, amount, ""),
            L1_CHAIN_SELECTOR,
            address(bridgeL2)
        );

        vm.prank(s_conceroRouter);
        bridgeL2.conceroReceive(
            messageRequest.toMessageReceiptBytes(
                L1_CHAIN_SELECTOR,
                address(bridgeL1),
                1,
                new bytes[](0)
            ),
            s_validationChecks,
            s_validatorLibs,
            s_relayerLib
        );
    }

    function _simulateL1Receive(address recipient, uint256 amount) internal {
        IConceroRouter.MessageRequest memory messageRequest = _buildMessageRequest(
            BridgeCodec.encodeBridgeData(recipient, recipient, amount, ""),
            L2_CHAIN_SELECTOR,
            address(bridgeL1)
        );

        vm.prank(s_conceroRouter);
        bridgeL1.conceroReceive(
            messageRequest.toMessageReceiptBytes(
                L2_CHAIN_SELECTOR,
                address(bridgeL2),
                1,
                new bytes[](0)
            ),
            s_validationChecks,
            s_validatorLibs,
            s_relayerLib
        );
    }

    function _getL1MessageFee() internal view returns (uint256) {
        return
            bridgeL1.getBridgeNativeFee(
                0,
                L2_CHAIN_SELECTOR,
                MessageCodec.encodeEvmDstChainData(address(bridgeL2), 0),
                ""
            );
    }

    function _getL2MessageFee() internal view returns (uint256) {
        return
            bridgeL2.getBridgeNativeFee(
                0,
                L1_CHAIN_SELECTOR,
                MessageCodec.encodeEvmDstChainData(address(bridgeL1), 0),
                ""
            );
    }
}
