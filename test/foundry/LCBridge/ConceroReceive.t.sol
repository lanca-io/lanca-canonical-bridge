// SPDX-License-Identifier: UNLICENSED
/* solhint-disable func-name-mixedcase */
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {CommonErrors} from "@concero/messaging-contracts-v2/contracts/common/CommonErrors.sol";

import {LCBridgeTest} from "./base/LCBridgeTest.sol";
import {MockInvalidLCBridgeClient} from "../mocks/MockInvalidLCBridgeClient.sol";
import {MockUSDCe} from "../mocks/MockUSDCe.sol";
import {ILancaCanonicalBridgeClient} from "contracts/interfaces/ILancaCanonicalBridgeClient.sol";
import {LancaCanonicalBridgeBase} from "contracts/LancaCanonicalBridge/LancaCanonicalBridgeBase.sol";
import {LancaCanonicalBridge} from "contracts/LancaCanonicalBridge/LancaCanonicalBridge.sol";

contract ConceroReceiveTest is LCBridgeTest {
    function setUp() public override {
        super.setUp();
    }

    // --- Tests for conceroReceive with no call ---

    function test_conceroReceive_Success() public {
        bytes memory message = _encodeBridgeParams(user, user, AMOUNT, false, "");
        uint256 userBalanceBefore = MockUSDCe(usdcE).balanceOf(user);
        uint256 totalSupplyBefore = MockUSDCe(usdcE).totalSupply();

        vm.prank(conceroRouter);
        lancaCanonicalBridge.conceroReceive(
            DEFAULT_MESSAGE_ID,
            SRC_CHAIN_SELECTOR,
            abi.encode(lancaBridgeL1Mock),
            message
        );

        uint256 userBalanceAfter = MockUSDCe(usdcE).balanceOf(user);
        uint256 totalSupplyAfter = MockUSDCe(usdcE).totalSupply();

        assertEq(userBalanceAfter, userBalanceBefore + AMOUNT);
        assertEq(totalSupplyAfter, totalSupplyBefore + AMOUNT);
    }

    function test_conceroReceive_RevertsInvalidSenderBridge() public {
        bytes memory message = _encodeBridgeParams(user, user, AMOUNT, false, "");

        vm.expectRevert(
            abi.encodeWithSelector(LancaCanonicalBridgeBase.InvalidBridgeSender.selector)
        );

        vm.prank(conceroRouter);
        lancaCanonicalBridge.conceroReceive(
            DEFAULT_MESSAGE_ID,
            SRC_CHAIN_SELECTOR,
            abi.encode(address(0)),
            message
        );
    }

    function test_conceroReceive_RevertsInvalidMessageType() public {
        bytes memory invalidMessage = abi.encode(uint8(3), abi.encode(user, user, AMOUNT));

        vm.expectRevert(
            abi.encodeWithSelector(LancaCanonicalBridgeBase.InvalidBridgeType.selector)
        );

        vm.prank(conceroRouter);
        lancaCanonicalBridge.conceroReceive(
            DEFAULT_MESSAGE_ID,
            SRC_CHAIN_SELECTOR,
            abi.encode(lancaBridgeL1Mock),
            invalidMessage
        );
    }

    function test_conceroReceive_EmitsBridgeDelivered() public {
        bytes memory message = _encodeBridgeParams(user, user, AMOUNT, false, "");

        vm.expectEmit(true, true, true, true);
        emit LancaCanonicalBridgeBase.BridgeDelivered(
            DEFAULT_MESSAGE_ID,
            address(lancaBridgeL1Mock),
            SRC_CHAIN_SELECTOR,
            user,
            user,
            AMOUNT
        );

        vm.prank(conceroRouter);
        lancaCanonicalBridge.conceroReceive(
            DEFAULT_MESSAGE_ID,
            SRC_CHAIN_SELECTOR,
            abi.encode(lancaBridgeL1Mock),
            message
        );
    }

    // --- Tests for conceroReceive with call ---

    function test_conceroReceive_WithCall_RevertsCallFiled() public {
        MockInvalidLCBridgeClient invalidLCBridgeClient = new MockInvalidLCBridgeClient();

        bytes memory message = _encodeBridgeParams(
            user,
            address(invalidLCBridgeClient),
            AMOUNT,
            true,
            ""
        );

        vm.expectRevert(abi.encodeWithSelector(ILancaCanonicalBridgeClient.CallFiled.selector));

        vm.prank(conceroRouter);
        lancaCanonicalBridge.conceroReceive(
            DEFAULT_MESSAGE_ID,
            SRC_CHAIN_SELECTOR,
            abi.encode(lancaBridgeL1Mock),
            message
        );
    }

    function test_conceroReceive_WithCall() public {
        string memory testString = "LancaCanonicalBridge";

        bytes memory message = _encodeBridgeParams(
            user,
            address(lcBridgeClient),
            AMOUNT,
            true,
            abi.encode(testString)
        );

        vm.prank(conceroRouter);
        lancaCanonicalBridge.conceroReceive(
            DEFAULT_MESSAGE_ID,
            SRC_CHAIN_SELECTOR,
            abi.encode(lancaBridgeL1Mock),
            message
        );

        assertEq(lcBridgeClient.token(), address(usdcE));
        assertEq(lcBridgeClient.tokenSender(), user);
        assertEq(lcBridgeClient.tokenAmount(), AMOUNT);
        assertEq(lcBridgeClient.testString(), testString);
    }

    function test_conceroReceive_WithCall_EmptyCallData() public {
        bytes memory message = _encodeBridgeParams(user, address(lcBridgeClient), AMOUNT, true, "");

        vm.prank(conceroRouter);
        lancaCanonicalBridge.conceroReceive(
            DEFAULT_MESSAGE_ID,
            SRC_CHAIN_SELECTOR,
            abi.encode(lancaBridgeL1Mock),
            message
        );

        assertEq(lcBridgeClient.token(), address(usdcE));
        assertEq(lcBridgeClient.tokenSender(), user);
        assertEq(lcBridgeClient.tokenAmount(), AMOUNT);
        assertEq(lcBridgeClient.testString(), "");
    }
}
