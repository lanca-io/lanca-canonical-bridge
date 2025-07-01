// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {CommonErrors} from "@concero/messaging-contracts-v2/contracts/common/CommonErrors.sol";

import {LCBridgeTest} from "./base/LCBridgeTest.sol";
import {MockUSDCe} from "../mocks/MockUSDCe.sol";
import {LancaCanonicalBridgeBase} from "contracts/LancaCanonicalBridge/LancaCanonicalBridgeBase.sol";
import {LancaCanonicalBridge} from "contracts/LancaCanonicalBridge/LancaCanonicalBridge.sol";

contract ConceroReceiveTest is LCBridgeTest {
    function setUp() public override {
        super.setUp();
    }

    function test_conceroReceive_Success() public {
        bytes memory message = abi.encode(user, AMOUNT);
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

    function test_conceroReceive_RevertsTransferFailed() public {
        MockUSDCe(usdcE).setShouldFailMint(true);

        bytes memory message = abi.encode(user, AMOUNT);

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
        bytes memory message = abi.encode(user, AMOUNT);

        vm.expectEmit(true, true, true, true);
        emit LancaCanonicalBridgeBase.TokenReceived(
            DEFAULT_MESSAGE_ID,
            SRC_CHAIN_SELECTOR,
            address(bytes20(abi.encode(lancaBridgeL1Mock))),
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

    function test_conceroReceive_WithCall() public {
        string memory testString = "LancaCanonicalBridgeL1";
        bytes memory message = abi.encode(
            user,
            AMOUNT,
            address(lcBridgeClient),
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
}
