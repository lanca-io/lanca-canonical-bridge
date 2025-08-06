// SPDX-License-Identifier: UNLICENSED
/* solhint-disable func-name-mixedcase */
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {CommonErrors} from "@concero/v2-contracts/contracts/common/CommonErrors.sol";

import {LCBridgeTest} from "./base/LCBridgeTest.sol";
import {MaliciousToken} from "../mocks/MaliciousToken.sol";
import {MockUSDCe} from "../mocks/MockUSDCe.sol";
import {ReentrancyGuard} from "contracts/common/ReentrancyGuard.sol";
import {LancaCanonicalBridgeBase} from "contracts/LancaCanonicalBridge/LancaCanonicalBridgeBase.sol";
import {LancaCanonicalBridge} from "contracts/LancaCanonicalBridge/LancaCanonicalBridge.sol";

contract SendTokenTest is LCBridgeTest {
    function setUp() public override {
        super.setUp();
    }

    function test_sendToken_RevertsInvalidAmount() public {
        uint256 invalidAmount = 0;

        vm.expectRevert(abi.encodeWithSelector(CommonErrors.InvalidAmount.selector));

        lancaCanonicalBridge.sendToken(user, invalidAmount, ZERO_AMOUNT, ZERO_BYTES);
    }

    function test_sendToken_Success() public {
        uint256 messageFee = _getMessageFee();

        _approveBridge(AMOUNT);

        uint256 userBalanceBefore = MockUSDCe(usdcE).balanceOf(user);
        uint256 totalSupplyBefore = MockUSDCe(usdcE).totalSupply();

		bytes memory message = _encodeBridgeParams(user, user, AMOUNT, ZERO_AMOUNT, ZERO_BYTES);
		bytes32 expectedMessageId = _getMessageId(SRC_CHAIN_SELECTOR, false, address(0), message);

        vm.prank(user);
        bytes32 messageId = lancaCanonicalBridge.sendToken{value: messageFee}(
            user,
            AMOUNT,
            ZERO_AMOUNT,
            ZERO_BYTES
        );

        uint256 userBalanceAfter = MockUSDCe(usdcE).balanceOf(user);
        uint256 totalSupplyAfter = MockUSDCe(usdcE).totalSupply();

        assertEq(messageId, expectedMessageId);
        assertEq(userBalanceAfter, userBalanceBefore - AMOUNT);
        assertEq(totalSupplyAfter, totalSupplyBefore - AMOUNT);
    }

    function test_sendToken_EmitsTokenSent() public {
        uint256 messageFee = _getMessageFee();

        _approveBridge(AMOUNT);

		bytes memory message = _encodeBridgeParams(user, user, AMOUNT, ZERO_AMOUNT, ZERO_BYTES);
		bytes32 messageId = _getMessageId(SRC_CHAIN_SELECTOR, false, address(0), message);

        vm.expectEmit(true, true, true, true);
        emit LancaCanonicalBridgeBase.TokenSent(
            messageId,
            user,
            user,
            AMOUNT
        );

        vm.prank(user);
        lancaCanonicalBridge.sendToken{value: messageFee}(
            user,
            AMOUNT,
            ZERO_AMOUNT,
            ZERO_BYTES
        );
    }

    function test_sendToken_WithContractCall() public {
        uint256 messageFee = lancaCanonicalBridge.getBridgeNativeFee(GAS_LIMIT);

        _approveBridge(AMOUNT);

        bytes memory callData = abi.encode("test data");

		bytes memory message = _encodeBridgeParams(user, address(lcBridgeClient), AMOUNT, GAS_LIMIT, callData);
		bytes32 expectedMessageId = _getMessageId(SRC_CHAIN_SELECTOR, false, address(0), message);

        vm.prank(user);
        bytes32 messageId = lancaCanonicalBridge.sendToken{value: messageFee}(
            address(lcBridgeClient),
            AMOUNT,
            GAS_LIMIT,
            callData
        );

        assertEq(messageId, expectedMessageId);
    }

    function test_sendToken_RevertsOnReentrancyAttack() public {
        MaliciousToken maliciousToken = new MaliciousToken();

        LancaCanonicalBridge newBridge = LancaCanonicalBridge(
            deploy(
                SRC_CHAIN_SELECTOR,
                conceroRouter,
                address(maliciousToken),
                lancaBridgeL1Mock,
                deployer
            )
        );

        vm.startPrank(deployer);
        newBridge.setRateLimit(SRC_CHAIN_SELECTOR, MAX_RATE_AMOUNT, REFILL_SPEED, true);
        newBridge.setRateLimit(SRC_CHAIN_SELECTOR, MAX_RATE_AMOUNT, REFILL_SPEED, false);
        vm.stopPrank();

        maliciousToken.setMinter(address(newBridge));
        maliciousToken.mintTo(user, AMOUNT * 2);

        vm.deal(user, 1e18);

        uint256 messageFee = newBridge.getBridgeNativeFee(ZERO_AMOUNT);

        maliciousToken.setAttackMode(true, address(newBridge));

        vm.prank(user);
        maliciousToken.approve(address(newBridge), AMOUNT);

        vm.expectRevert(abi.encodeWithSelector(ReentrancyGuard.ReentrantCall.selector));

        vm.prank(user);
        newBridge.sendToken{value: messageFee}(user, AMOUNT, ZERO_AMOUNT, ZERO_BYTES);
    }

    function test_sendToken_RevertsInvalidDstGasLimitOrCallData() public {
        uint256 messageFee = _getMessageFee();

        _approveBridge(AMOUNT);
        bytes memory nonZeroBytes = "0x01";

        vm.expectRevert(abi.encodeWithSelector(LancaCanonicalBridgeBase.InvalidDstGasLimitOrCallData.selector));

        vm.prank(user);
        lancaCanonicalBridge.sendToken{value: messageFee}(
            user,
            AMOUNT,
            ZERO_AMOUNT,
            nonZeroBytes
        );

        uint256 nonZeroGasLimit = GAS_LIMIT;

        vm.expectRevert(abi.encodeWithSelector(LancaCanonicalBridgeBase.InvalidDstGasLimitOrCallData.selector));

        vm.prank(user);
        lancaCanonicalBridge.sendToken{value: messageFee}(
            user,
            AMOUNT,
            nonZeroGasLimit,
            ZERO_BYTES
        );
    }
}
