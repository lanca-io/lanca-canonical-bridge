// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {CommonErrors} from "@concero/messaging-contracts-v2/contracts/common/CommonErrors.sol";

import {LCBridgeL1Test} from "./base/LCBridgeL1Test.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";
import {ReentrancyGuard} from "contracts/common/ReentrancyGuard.sol";
import {LancaCanonicalBridgeBase} from "contracts/LancaCanonicalBridge/LancaCanonicalBridgeBase.sol";
import {LancaCanonicalBridgeL1} from "contracts/LancaCanonicalBridge/LancaCanonicalBridgeL1.sol";

contract ConceroReceiveL1Test is LCBridgeL1Test {
    function setUp() public override {
        super.setUp();
    }

    function test_conceroReceive_RevertsPoolNotFound() public {
        bytes memory message = abi.encode(user, AMOUNT);

        vm.expectRevert(
            abi.encodeWithSelector(LancaCanonicalBridgeL1.PoolNotFound.selector, SRC_CHAIN_SELECTOR)
        );

        vm.prank(conceroRouter);
        lancaCanonicalBridgeL1.conceroReceive(
            DEFAULT_MESSAGE_ID,
            SRC_CHAIN_SELECTOR,
            abi.encode(lancaBridgeMock),
            message
        );
    }

    function test_conceroReceive_RevertsTransferFailed() public {
        _addDefaultPool();

        MockUSDC(usdc).setShouldFailTransfer(true);

        bytes memory message = abi.encode(user, AMOUNT);

        vm.expectRevert(abi.encodeWithSelector(CommonErrors.TransferFailed.selector));

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

        MockUSDC(usdc).mint(address(lancaCanonicalBridgePool), AMOUNT);

        bytes memory message = abi.encode(user, AMOUNT);
        uint256 userBalanceBefore = MockUSDC(usdc).balanceOf(user);

        vm.prank(conceroRouter);
        lancaCanonicalBridgeL1.conceroReceive(
            DEFAULT_MESSAGE_ID,
            DST_CHAIN_SELECTOR,
            abi.encode(lancaBridgeMock),
            message
        );

        assertEq(MockUSDC(usdc).balanceOf(user), userBalanceBefore + AMOUNT);
    }

    function test_conceroReceive_EmitsTokenReceived() public {
        _addDefaultPool();

        MockUSDC(usdc).mint(address(lancaCanonicalBridgePool), AMOUNT);

        bytes memory message = abi.encode(user, AMOUNT);

        vm.expectEmit(true, true, true, true);
        emit LancaCanonicalBridgeBase.TokenReceived(
            DEFAULT_MESSAGE_ID,
            DST_CHAIN_SELECTOR,
            address(bytes20(abi.encode(lancaBridgeMock))),
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
