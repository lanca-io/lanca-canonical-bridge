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

import {BridgeCodec} from "contracts/common/libraries/BridgeCodec.sol";
import {LancaCanonicalBridgeBase} from "contracts/LancaCanonicalBridge/LancaCanonicalBridgeBase.sol";
import {LancaCanonicalBridgeL1} from "contracts/LancaCanonicalBridge/LancaCanonicalBridgeL1.sol";

import {MockInvalidClient} from "../mocks/MockInvalidClient.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";
import {LCBridgeL1Base} from "./LCBridgeL1Base.sol";

contract ConceroReceiveL1Test is LCBridgeL1Base {
    using MessageCodec for IConceroRouter.MessageRequest;

    function setUp() public override {
        super.setUp();
    }

    function test_conceroReceive_Success() public {
        _beforeConceroReceive();

        uint256 userBalanceBefore = s_usdc.balanceOf(s_user);
        uint256 poolBalanceBefore = s_usdc.balanceOf(address(lancaCanonicalBridgePool));

        _conceroReceive(s_user, s_user, AMOUNT, 0, ZERO_BYTES);

        uint256 userBalanceAfter = s_usdc.balanceOf(s_user);
        uint256 poolBalanceAfter = s_usdc.balanceOf(address(lancaCanonicalBridgePool));

        assertEq(userBalanceAfter, userBalanceBefore + AMOUNT);
        assertEq(poolBalanceAfter, poolBalanceBefore - AMOUNT);
    }

    function test_conceroReceive_RevertsInvalidSenderBridge() public {
        IConceroRouter.MessageRequest memory messageRequest = _buildMessageRequest(
            BridgeCodec.encodeBridgeData(
                s_user,
                AMOUNT,
                MessageCodec.encodeEvmDstChainData(s_user, 0),
                ZERO_BYTES
            ),
            SRC_CHAIN_SELECTOR,
            address(lancaCanonicalBridgeL1)
        );

        address invalidBridgeL1 = address(999);

        vm.expectRevert(
            abi.encodeWithSelector(LancaCanonicalBridgeBase.InvalidBridgeSender.selector)
        );

        vm.prank(s_conceroRouter);
        lancaCanonicalBridgeL1.conceroReceive(
            messageRequest.toMessageReceiptBytes(
                SRC_CHAIN_SELECTOR,
                invalidBridgeL1,
                NONCE,
                new bytes[](0)
            ),
            s_validationChecks,
            s_validatorLibs,
            s_relayerLib
        );
    }

    function test_conceroReceive_EmitsBridgeDelivered() public {
        _beforeConceroReceive();

        vm.expectEmit(false, false, false, true);
        emit LancaCanonicalBridgeBase.BridgeDelivered(DEFAULT_MESSAGE_ID, AMOUNT);

        _conceroReceive(s_user, s_user, AMOUNT, 0, ZERO_BYTES);
    }

    function test_conceroReceive_RevertsPoolNotFound() public {
        _addDefaultDstBridge();

        vm.expectRevert(
            abi.encodeWithSelector(LancaCanonicalBridgeL1.PoolNotFound.selector, DST_CHAIN_SELECTOR)
        );

        _conceroReceive(s_user, s_user, AMOUNT, 0, ZERO_BYTES);
    }

    // --- Tests for conceroReceive with call ---

    function test_conceroReceive_WithCall_DeliversTokensWithoutHookWhenReceiverHasNoCode() public {
        _beforeConceroReceive();

        address invalidLCBridgeClient = makeAddr("InvalidLCBridgeClient");

        _conceroReceive(s_user, invalidLCBridgeClient, AMOUNT, GAS_LIMIT, "0x01");

        assertEq(s_usdc.balanceOf(invalidLCBridgeClient), AMOUNT);
    }

    function test_conceroReceive_WithCall_DeliversTokensWhenReceiverLacksInterface() public {
        _beforeConceroReceive();

        MockInvalidClient invalidReceiverContract = new MockInvalidClient();

        _conceroReceive(s_user, address(invalidReceiverContract), AMOUNT, GAS_LIMIT, "0x01");

        assertEq(s_usdc.balanceOf(address(invalidReceiverContract)), AMOUNT);
    }

    function test_conceroReceive_WithCall() public {
        _beforeConceroReceive();

        string memory testString = "LancaCanonicalBridgeL1";

        _conceroReceive(s_user, address(lcBridgeClient), AMOUNT, GAS_LIMIT, abi.encode(testString));

        assertEq(lcBridgeClient.srcChainSelector(), DST_CHAIN_SELECTOR);
        assertEq(BridgeCodec.toAddress(lcBridgeClient.tokenSender()), s_user);
        assertEq(lcBridgeClient.tokenAmount(), AMOUNT);
        assertEq(lcBridgeClient.testString(), testString);
    }

    // --- Helper Functions ---

    function _beforeConceroReceive() internal {
        _addDefaultPool();
        _addDefaultDstBridge();

        MockUSDC(address(s_usdc)).mint(address(lancaCanonicalBridgePool), AMOUNT);
    }
}
