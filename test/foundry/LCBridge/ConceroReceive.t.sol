// SPDX-License-Identifier: UNLICENSED
/* solhint-disable func-name-mixedcase */
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {IConceroRouter} from "@concero/v2-contracts/contracts/interfaces/IConceroRouter.sol";
import {MessageCodec} from "@concero/v2-contracts/contracts/common/libraries/MessageCodec.sol";

import {LancaCanonicalBridgeBase} from "contracts/LancaCanonicalBridge/LancaCanonicalBridgeBase.sol";
import {BridgeCodec} from "contracts/common/libraries/BridgeCodec.sol";

import {MockUSDCe} from "../mocks/MockUSDCe.sol";
import {LCBridgeBase} from "./LCBridgeBase.sol";

contract ConceroReceiveTest is LCBridgeBase {
    using MessageCodec for IConceroRouter.MessageRequest;

    function setUp() public override {
        super.setUp();
    }

    // --- Tests for conceroReceive with no call ---

    function test_conceroReceive_Success() public {
        uint256 userBalanceBefore = s_usdcE.balanceOf(s_user);
        uint256 totalSupplyBefore = s_usdcE.totalSupply();

        _conceroReceive(s_user, s_user, AMOUNT, 0, "");

        uint256 userBalanceAfter = s_usdcE.balanceOf(s_user);
        uint256 totalSupplyAfter = s_usdcE.totalSupply();

        assertEq(userBalanceAfter, userBalanceBefore + AMOUNT);
        assertEq(totalSupplyAfter, totalSupplyBefore + AMOUNT);
    }

    function test_conceroReceive_RevertsInvalidSenderBridge() public {
        IConceroRouter.MessageRequest memory messageRequest = _buildMessageRequest(
            BridgeCodec.encodeBridgeData(
                s_user,
                AMOUNT,
                MessageCodec.encodeEvmDstChainData(s_user, 0),
                ""
            ),
            SRC_CHAIN_SELECTOR,
            address(lancaCanonicalBridge)
        );

        address invalidBridgeL1 = address(999);
        uint24 invalidSrcChainSelector = 999;

        vm.expectRevert(
            abi.encodeWithSelector(LancaCanonicalBridgeBase.InvalidBridgeSender.selector)
        );

        vm.prank(s_conceroRouter);
        lancaCanonicalBridge.conceroReceive(
            messageRequest.toMessageReceiptBytes(SRC_CHAIN_SELECTOR, invalidBridgeL1, NONCE),
            s_validationChecks,
            s_validatorLibs,
            s_relayerLib
        );

        vm.expectRevert(
            abi.encodeWithSelector(LancaCanonicalBridgeBase.InvalidBridgeSender.selector)
        );

        vm.prank(s_conceroRouter);
        lancaCanonicalBridge.conceroReceive(
            messageRequest.toMessageReceiptBytes(
                invalidSrcChainSelector,
                s_lancaBridgeL1Mock,
                NONCE
            ),
            s_validationChecks,
            s_validatorLibs,
            s_relayerLib
        );
    }

    function test_conceroReceive_EmitsBridgeDelivered() public {
        vm.expectEmit(false, false, false, true);
        emit LancaCanonicalBridgeBase.BridgeDelivered(DEFAULT_MESSAGE_ID, AMOUNT);

        _conceroReceive(s_user, s_user, AMOUNT, 0, "");
    }

    // --- Tests for conceroReceive with call ---

    function test_conceroReceive_WithCall_RevertsCallFiled() public {
        address invalidLCBridgeClient = makeAddr("InvalidLCBridgeClient");

        vm.expectRevert(
            abi.encodeWithSelector(LancaCanonicalBridgeBase.InvalidConceroMessage.selector)
        );

        _conceroReceive(s_user, invalidLCBridgeClient, AMOUNT, GAS_LIMIT, "0x01");
    }

    function test_conceroReceive_WithCall() public {
        string memory testString = "LancaCanonicalBridge";

        _conceroReceive(s_user, address(lcBridgeClient), AMOUNT, GAS_LIMIT, abi.encode(testString));

        assertEq(lcBridgeClient.srcChainSelector(), SRC_CHAIN_SELECTOR);
        assertEq(BridgeCodec.toAddress(lcBridgeClient.tokenSender()), s_user);
        assertEq(lcBridgeClient.tokenAmount(), AMOUNT);
        assertEq(lcBridgeClient.testString(), testString);
    }
}
