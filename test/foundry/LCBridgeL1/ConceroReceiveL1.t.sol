// SPDX-License-Identifier: UNLICENSED
/* solhint-disable func-name-mixedcase */
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {CommonErrors} from "@concero/v2-contracts/contracts/common/CommonErrors.sol";

import {LCBridgeL1Test} from "./base/LCBridgeL1Test.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";
import {LancaCanonicalBridgeBase} from "contracts/LancaCanonicalBridge/LancaCanonicalBridgeBase.sol";
import {LancaCanonicalBridgeL1} from "contracts/LancaCanonicalBridge/LancaCanonicalBridgeL1.sol";

contract ConceroReceiveL1Test is LCBridgeL1Test {
    function setUp() public override {
        super.setUp();
    }

    function test_conceroReceive_RevertsInvalidSenderBridge() public {
        bytes memory message = _encodeBridgeParams(user, user, AMOUNT, 0, "");

        vm.expectRevert(
            abi.encodeWithSelector(LancaCanonicalBridgeBase.InvalidBridgeSender.selector)
        );

        vm.prank(conceroRouter);
        lancaCanonicalBridgeL1.conceroReceive(
            DEFAULT_MESSAGE_ID,
            DST_CHAIN_SELECTOR,
            abi.encode(lancaBridgeMock),
            message
        );
    }

    function test_conceroReceive_RevertsPoolNotFound() public {
        _addDefaultDstBridge();

        bytes memory message = _encodeBridgeParams(user, user, AMOUNT, 0, "");

        vm.expectRevert(
            abi.encodeWithSelector(LancaCanonicalBridgeL1.PoolNotFound.selector, DST_CHAIN_SELECTOR)
        );

        vm.prank(conceroRouter);
        lancaCanonicalBridgeL1.conceroReceive(
            DEFAULT_MESSAGE_ID,
            DST_CHAIN_SELECTOR,
            abi.encode(lancaBridgeMock),
            message
        );
    }

    function test_conceroReceive_Success() public {
        _addDefaultPool();
        _addDefaultDstBridge();

        MockUSDC(usdc).mint(address(lancaCanonicalBridgePool), AMOUNT);

        uint256 userBalanceBefore = MockUSDC(usdc).balanceOf(user);
        uint256 poolBalanceBefore = MockUSDC(usdc).balanceOf(address(lancaCanonicalBridgePool));

        bytes memory message = _encodeBridgeParams(user, user, AMOUNT, 0, "");

        vm.prank(conceroRouter);
        lancaCanonicalBridgeL1.conceroReceive(
            DEFAULT_MESSAGE_ID,
            DST_CHAIN_SELECTOR,
            abi.encode(lancaBridgeMock),
            message
        );

        uint256 userBalanceAfter = MockUSDC(usdc).balanceOf(user);
        uint256 poolBalanceAfter = MockUSDC(usdc).balanceOf(address(lancaCanonicalBridgePool));

        assertEq(userBalanceAfter, userBalanceBefore + AMOUNT);
        assertEq(poolBalanceAfter, poolBalanceBefore - AMOUNT);
    }

    function test_conceroReceive_EmitsBridgeDelivered() public {
        _addDefaultPool();
        _addDefaultDstBridge();

        MockUSDC(usdc).mint(address(lancaCanonicalBridgePool), AMOUNT);

        bytes memory message = _encodeBridgeParams(user, user, AMOUNT, 0, "");

        vm.expectEmit(true, true, true, true);
        emit LancaCanonicalBridgeBase.BridgeDelivered(
            DEFAULT_MESSAGE_ID,
            lancaBridgeMock,
            DST_CHAIN_SELECTOR,
            user,
            user,
            AMOUNT
        );

        vm.prank(conceroRouter);
        lancaCanonicalBridgeL1.conceroReceive(
            DEFAULT_MESSAGE_ID,
            DST_CHAIN_SELECTOR,
            abi.encode(lancaBridgeMock),
            message
        );
    }
}
