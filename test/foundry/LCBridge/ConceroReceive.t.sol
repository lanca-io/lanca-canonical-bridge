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

import {LCBridgeTest} from "./base/LCBridgeTest.sol";
import {MockUSDCe} from "../mocks/MockUSDCe.sol";
import {LancaCanonicalBridgeBase} from "contracts/LancaCanonicalBridge/LancaCanonicalBridgeBase.sol";

contract ConceroReceiveTest is LCBridgeTest {
    using MessageCodec for IConceroRouter.MessageRequest;
    using MessageCodec for bytes;

    function setUp() public override {
        super.setUp();
    }

    // --- Tests for conceroReceive with no call ---

    function test_conceroReceive_Success() public {
        uint256 userBalanceBefore = MockUSDCe(usdcE).balanceOf(user);
        uint256 totalSupplyBefore = MockUSDCe(usdcE).totalSupply();

        _conceroReceive(user, user, AMOUNT, 0, "");

        uint256 userBalanceAfter = MockUSDCe(usdcE).balanceOf(user);
        uint256 totalSupplyAfter = MockUSDCe(usdcE).totalSupply();

        assertEq(userBalanceAfter, userBalanceBefore + AMOUNT);
        assertEq(totalSupplyAfter, totalSupplyBefore + AMOUNT);
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
        uint24 invalidSrcChainSelector = 999;

        bool[] memory validationChecks = new bool[](1);
        validationChecks[0] = true;
        address[] memory validatorLibs = new address[](1);
        validatorLibs[0] = validatorLib;

        vm.expectRevert(
            abi.encodeWithSelector(LancaCanonicalBridgeBase.InvalidBridgeSender.selector)
        );

        vm.prank(conceroRouter);
        lancaCanonicalBridge.conceroReceive(
            messageRequest.toMessageReceiptBytes(SRC_CHAIN_SELECTOR, invalidBridgeL1, NONCE),
            validationChecks,
            validatorLibs,
            relayerLib
        );

        vm.expectRevert(
            abi.encodeWithSelector(LancaCanonicalBridgeBase.InvalidBridgeSender.selector)
        );

        vm.prank(conceroRouter);
        lancaCanonicalBridge.conceroReceive(
            messageRequest.toMessageReceiptBytes(invalidSrcChainSelector, lancaBridgeL1Mock, NONCE),
            validationChecks,
            validatorLibs,
            relayerLib
        );
    }

    function test_conceroReceive_EmitsBridgeDelivered() public {
        vm.expectEmit(false, false, false, true);
        emit LancaCanonicalBridgeBase.BridgeDelivered(DEFAULT_MESSAGE_ID, AMOUNT);

        _conceroReceive(user, user, AMOUNT, 0, "");
    }

    //     // --- Tests for conceroReceive with call ---

    function test_conceroReceive_WithCall_RevertsCallFiled() public {
        address invalidLCBridgeClient = makeAddr("InvalidLCBridgeClient");

        vm.expectRevert(
            abi.encodeWithSelector(LancaCanonicalBridgeBase.InvalidConceroMessage.selector)
        );

        _conceroReceive(user, invalidLCBridgeClient, AMOUNT, GAS_LIMIT, "0x01");
    }

    function test_conceroReceive_WithCall() public {
        string memory testString = "LancaCanonicalBridge";

        _conceroReceive(user, address(lcBridgeClient), AMOUNT, GAS_LIMIT, abi.encode(testString));

        assertEq(lcBridgeClient.srcChainSelector(), SRC_CHAIN_SELECTOR);
        assertEq(lcBridgeClient.tokenSender(), user);
        assertEq(lcBridgeClient.tokenAmount(), AMOUNT);
        assertEq(lcBridgeClient.testString(), testString);
    }

    // --- Helper functions ---

    function _conceroReceive(
        address tokenSender,
        address tokenReceiver,
        uint256 tokenAmount,
        uint256 dstGasLimit,
        bytes memory dstCallData
    ) internal {
        IConceroRouter.MessageRequest memory messageRequest = _buildMessageRequest(
            tokenSender,
            tokenReceiver,
            tokenAmount,
            dstGasLimit,
            dstCallData
        );

        bool[] memory validationChecks = new bool[](1);
        validationChecks[0] = true;
        address[] memory validatorLibs = new address[](1);
        validatorLibs[0] = validatorLib;

        vm.prank(conceroRouter);
        lancaCanonicalBridge.conceroReceive(
            messageRequest.toMessageReceiptBytes(SRC_CHAIN_SELECTOR, lancaBridgeL1Mock, NONCE),
            validationChecks,
            validatorLibs,
            relayerLib
        );
    }
}
