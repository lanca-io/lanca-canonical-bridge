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

import {LCBridgeL1Test} from "./base/LCBridgeL1Test.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";
import {LancaCanonicalBridgeBase} from "contracts/LancaCanonicalBridge/LancaCanonicalBridgeBase.sol";
import {LancaCanonicalBridgeL1} from "contracts/LancaCanonicalBridge/LancaCanonicalBridgeL1.sol";

contract ConceroReceiveL1Test is LCBridgeL1Test {
    using MessageCodec for IConceroRouter.MessageRequest;
    using MessageCodec for bytes;

    function setUp() public override {
        super.setUp();
    }

    function test_conceroReceive_Success() public {
        _addDefaultPool();
        _addDefaultDstBridge();

        MockUSDC(usdc).mint(address(lancaCanonicalBridgePool), AMOUNT);

        uint256 userBalanceBefore = MockUSDC(usdc).balanceOf(user);
        uint256 poolBalanceBefore = MockUSDC(usdc).balanceOf(address(lancaCanonicalBridgePool));

        _conceroReceive(user, user, AMOUNT, 0, "");

        uint256 userBalanceAfter = MockUSDC(usdc).balanceOf(user);
        uint256 poolBalanceAfter = MockUSDC(usdc).balanceOf(address(lancaCanonicalBridgePool));

        assertEq(userBalanceAfter, userBalanceBefore + AMOUNT);
        assertEq(poolBalanceAfter, poolBalanceBefore - AMOUNT);
    }

    function test_conceroReceive_RevertsInvalidSenderBridge() public {
        IConceroRouter.MessageRequest memory messageRequest = _buildMessageRequest(
            user,
            user,
            AMOUNT,
            0,
            ""
        );

        address invalidBridgeL1 = address(999);

        bool[] memory validationChecks = new bool[](1);
        validationChecks[0] = true;
        address[] memory validatorLibs = new address[](1);
        validatorLibs[0] = validatorLib;

        vm.expectRevert(
            abi.encodeWithSelector(LancaCanonicalBridgeBase.InvalidBridgeSender.selector)
        );

        vm.prank(conceroRouter);
        lancaCanonicalBridgeL1.conceroReceive(
            messageRequest.toMessageReceiptBytes(SRC_CHAIN_SELECTOR, invalidBridgeL1, NONCE),
            validationChecks,
            validatorLibs,
            relayerLib
        );
    }

    function test_conceroReceive_EmitsBridgeDelivered() public {
        _addDefaultPool();
        _addDefaultDstBridge();

        MockUSDC(usdc).mint(address(lancaCanonicalBridgePool), AMOUNT);

        vm.expectEmit(false, false, false, true);
        emit LancaCanonicalBridgeBase.BridgeDelivered(DEFAULT_MESSAGE_ID, AMOUNT);

        _conceroReceive(user, user, AMOUNT, 0, "");
    }

    function test_conceroReceive_RevertsPoolNotFound() public {
        _addDefaultDstBridge();

        vm.expectRevert(
            abi.encodeWithSelector(LancaCanonicalBridgeL1.PoolNotFound.selector, DST_CHAIN_SELECTOR)
        );

        _conceroReceive(user, user, AMOUNT, 0, "");
    }

    function test_conceroReceive_WithCall_RevertsIfInvalidConceroMessage() public {
        _addDefaultPool();
        _addDefaultDstBridge();

        address invalidLCBridgeClient = makeAddr("InvalidLCBridgeClient");

        vm.expectRevert(
            abi.encodeWithSelector(LancaCanonicalBridgeBase.InvalidConceroMessage.selector)
        );

        _conceroReceive(user, invalidLCBridgeClient, AMOUNT, GAS_LIMIT, "0x01");
    }

    function test_conceroReceive_WithCall() public {
        _addDefaultPool();
        _addDefaultDstBridge();

        MockUSDC(usdc).mint(address(lancaCanonicalBridgePool), AMOUNT);

        string memory testString = "LancaCanonicalBridgeL1";

        _conceroReceive(user, address(lcBridgeClient), AMOUNT, GAS_LIMIT, abi.encode(testString));

        assertEq(lcBridgeClient.srcChainSelector(), DST_CHAIN_SELECTOR);
        assertEq(lcBridgeClient.tokenSender(), user);
        assertEq(lcBridgeClient.tokenAmount(), AMOUNT);
        assertEq(lcBridgeClient.testString(), testString);
    }
}
