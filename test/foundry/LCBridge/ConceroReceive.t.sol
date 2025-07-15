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
import {LancaCanonicalBridgeBase, LCBridgeCallData} from "contracts/LancaCanonicalBridge/LancaCanonicalBridgeBase.sol";
import {LancaCanonicalBridge} from "contracts/LancaCanonicalBridge/LancaCanonicalBridge.sol";

contract ConceroReceiveTest is LCBridgeTest {
    function setUp() public override {
        super.setUp();
    }

    // --- Tests for conceroReceive with no call ---

    function test_conceroReceive_Success() public {
        bytes memory message = _encodeBridgeParams(user, AMOUNT, false, "");
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
        bytes memory message = _encodeBridgeParams(user, AMOUNT, false, "");

        vm.expectRevert(
            abi.encodeWithSelector(LancaCanonicalBridgeBase.InvalidSenderBridge.selector)
        );

        vm.prank(conceroRouter);
        lancaCanonicalBridge.conceroReceive(
            DEFAULT_MESSAGE_ID,
            SRC_CHAIN_SELECTOR,
            abi.encode(address(0)),
            message
        );
    }

    function test_conceroReceive_RevertsTransferFailed() public {
        MockUSDCe(usdcE).setShouldFailMint(true);

        bytes memory message = _encodeBridgeParams(user, AMOUNT, false, "");

        vm.expectRevert(abi.encodeWithSelector(CommonErrors.TransferFailed.selector));

        vm.prank(conceroRouter);
        lancaCanonicalBridge.conceroReceive(
            DEFAULT_MESSAGE_ID,
            SRC_CHAIN_SELECTOR,
            abi.encode(lancaBridgeL1Mock),
            message
        );
    }

    function test_conceroReceive_EmitsTokenReceived() public {
        bytes memory message = _encodeBridgeParams(user, AMOUNT, false, "");

        vm.expectEmit(true, true, true, true);
        emit LancaCanonicalBridgeBase.TokenReceived(
            DEFAULT_MESSAGE_ID,
            SRC_CHAIN_SELECTOR,
            address(lancaBridgeL1Mock),
            address(0), // TODO: fix it
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
        string memory testString = "LancaCanonicalBridgeL1";

        bytes memory message = _encodeBridgeParams(
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
        assertEq(lcBridgeClient.tokenSender(), address(0)); // TODO: fix it
        assertEq(lcBridgeClient.tokenAmount(), AMOUNT);
        assertEq(lcBridgeClient.testString(), testString);
    }
}
