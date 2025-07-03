// SPDX-License-Identifier: UNLICENSED
/* solhint-disable func-name-mixedcase */
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {CommonErrors} from "@concero/messaging-contracts-v2/contracts/common/CommonErrors.sol";
import {ConceroTypes} from "@concero/messaging-contracts-v2/contracts/ConceroClient/ConceroTypes.sol";
import {IConceroClientErrors} from "@concero/messaging-contracts-v2/contracts/interfaces/IConceroClientErrors.sol";

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

        lancaCanonicalBridge.sendToken(
            invalidAmount,
            address(0),
            ConceroTypes.EvmDstChainData({receiver: lancaBridgeL1Mock, gasLimit: GAS_LIMIT})
        );
    }

    function test_sendToken_RevertsInsufficientFee() public {
        uint256 messageFee = lancaCanonicalBridge.getMessageFee(
            SRC_CHAIN_SELECTOR,
            address(0),
            ConceroTypes.EvmDstChainData({receiver: lancaBridgeL1Mock, gasLimit: GAS_LIMIT})
        );

        vm.expectRevert(
            abi.encodeWithSelector(IConceroClientErrors.InsufficientFee.selector, 0, messageFee)
        );

        lancaCanonicalBridge.sendToken(
            AMOUNT,
            address(0),
            ConceroTypes.EvmDstChainData({receiver: lancaBridgeL1Mock, gasLimit: GAS_LIMIT})
        );
    }

    function test_sendToken_RevertsTransferFailed() public {
        uint256 messageFee = lancaCanonicalBridge.getMessageFee(
            SRC_CHAIN_SELECTOR,
            address(0),
            ConceroTypes.EvmDstChainData({receiver: lancaBridgeL1Mock, gasLimit: GAS_LIMIT})
        );

        _approveBridge(AMOUNT);
        MockUSDCe(usdcE).setShouldFailTransfer(true);

        vm.expectRevert(abi.encodeWithSelector(CommonErrors.TransferFailed.selector));

        vm.prank(user);
        lancaCanonicalBridge.sendToken{value: messageFee}(
            AMOUNT,
            address(0),
            ConceroTypes.EvmDstChainData({receiver: lancaBridgeL1Mock, gasLimit: GAS_LIMIT})
        );
    }

    function test_sendToken_Success() public {
        uint256 messageFee = lancaCanonicalBridge.getMessageFee(
            SRC_CHAIN_SELECTOR,
            address(0),
            ConceroTypes.EvmDstChainData({receiver: lancaBridgeL1Mock, gasLimit: GAS_LIMIT})
        );

        _approveBridge(AMOUNT);

        uint256 userBalanceBefore = MockUSDCe(usdcE).balanceOf(user);
        uint256 totalSupplyBefore = MockUSDCe(usdcE).totalSupply();

        vm.prank(user);
        bytes32 messageId = lancaCanonicalBridge.sendToken{value: messageFee}(
            AMOUNT,
            address(0),
            ConceroTypes.EvmDstChainData({receiver: lancaBridgeL1Mock, gasLimit: GAS_LIMIT})
        );

        uint256 userBalanceAfter = MockUSDCe(usdcE).balanceOf(user);
        uint256 totalSupplyAfter = MockUSDCe(usdcE).totalSupply();

        assertEq(messageId, DEFAULT_MESSAGE_ID);
        assertEq(userBalanceAfter, userBalanceBefore - AMOUNT);
        assertEq(totalSupplyAfter, totalSupplyBefore - AMOUNT);
    }

    function test_sendToken_EmitsTokenSent() public {
        uint256 messageFee = lancaCanonicalBridge.getMessageFee(
            SRC_CHAIN_SELECTOR,
            address(0),
            ConceroTypes.EvmDstChainData({receiver: lancaBridgeL1Mock, gasLimit: GAS_LIMIT})
        );

        _approveBridge(AMOUNT);

        vm.expectEmit(true, true, true, true);
        emit LancaCanonicalBridgeBase.TokenSent(
            DEFAULT_MESSAGE_ID,
            lancaBridgeL1Mock,
            SRC_CHAIN_SELECTOR,
            user,
            AMOUNT,
            messageFee
        );

        vm.prank(user);
        lancaCanonicalBridge.sendToken{value: messageFee}(
            AMOUNT,
            address(0),
            ConceroTypes.EvmDstChainData({receiver: lancaBridgeL1Mock, gasLimit: GAS_LIMIT})
        );
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
        newBridge.setOutboundFlowLimit(MAX_FLOW_AMOUNT, REFILL_SPEED);
        newBridge.setInboundFlowLimit(MAX_FLOW_AMOUNT, REFILL_SPEED);
        vm.stopPrank();

        maliciousToken.setMinter(address(newBridge));
        maliciousToken.mintTo(user, AMOUNT * 2);

        vm.deal(user, 1e18);

        uint256 messageFee = newBridge.getMessageFee(
            SRC_CHAIN_SELECTOR,
            address(0),
            ConceroTypes.EvmDstChainData({receiver: lancaBridgeL1Mock, gasLimit: GAS_LIMIT})
        );

        maliciousToken.setAttackMode(true, address(newBridge));

        vm.prank(user);
        maliciousToken.approve(address(newBridge), AMOUNT);

        vm.expectRevert(abi.encodeWithSelector(ReentrancyGuard.ReentrantCall.selector));

        vm.prank(user);
        newBridge.sendToken{value: messageFee}(
            AMOUNT,
            address(0),
            ConceroTypes.EvmDstChainData({receiver: lancaBridgeL1Mock, gasLimit: GAS_LIMIT})
        );
    }
}
