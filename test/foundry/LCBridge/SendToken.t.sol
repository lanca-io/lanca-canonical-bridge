// SPDX-License-Identifier: UNLICENSED
/* solhint-disable func-name-mixedcase */
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {ReentrancyGuard} from "@openzeppelin/contracts-v5/utils/ReentrancyGuard.sol";

import {MessageCodec} from "@concero/v2-contracts/contracts/common/libraries/MessageCodec.sol";
import {CommonErrors} from "@concero/v2-contracts/contracts/common/CommonErrors.sol";

import {LancaCanonicalBridge} from "contracts/LancaCanonicalBridge/LancaCanonicalBridge.sol";
import {LancaCanonicalBridgeBase} from "contracts/LancaCanonicalBridge/LancaCanonicalBridgeBase.sol";

import {MaliciousToken} from "../mocks/MaliciousToken.sol";
import {MockUSDCe} from "../mocks/MockUSDCe.sol";
import {LCBridgeBase} from "./LCBridgeBase.sol";

contract SendTokenTest is LCBridgeBase {
    function setUp() public override {
        super.setUp();
    }

    function test_sendToken_RevertsInvalidAmount() public {
        uint256 invalidAmount = 0;

        vm.expectRevert(abi.encodeWithSelector(CommonErrors.InvalidAmount.selector));

        lancaCanonicalBridge.sendToken(
            invalidAmount,
            MessageCodec.encodeEvmDstChainData(address(s_lancaBridgeMock), 0),
            ZERO_BYTES
        );
    }

    function test_sendToken_Success() public {
        uint256 messageFee = _getMessageFee();

        _approveBridge(AMOUNT);

        uint256 userBalanceBefore = s_usdcE.balanceOf(s_user);
        uint256 totalSupplyBefore = s_usdcE.totalSupply();

        vm.prank(s_user);
        lancaCanonicalBridge.sendToken{value: messageFee}(
            AMOUNT,
            MessageCodec.encodeEvmDstChainData(address(s_lancaBridgeMock), 0),
            ZERO_BYTES
        );

        uint256 userBalanceAfter = s_usdcE.balanceOf(s_user);
        uint256 totalSupplyAfter = s_usdcE.totalSupply();

        assertEq(userBalanceAfter, userBalanceBefore - AMOUNT);
        assertEq(totalSupplyAfter, totalSupplyBefore - AMOUNT);
    }

    function test_sendToken_EmitsTokenSent() public {
        uint256 messageFee = _getMessageFee();

        _approveBridge(AMOUNT);

        bytes memory dstChainData = MessageCodec.encodeEvmDstChainData(
            address(s_lancaBridgeMock),
            0
        );

        vm.expectEmit(false, true, true, true);
        emit LancaCanonicalBridgeBase.TokenSent(
            bytes32(0),
            SRC_CHAIN_SELECTOR,
            dstChainData,
            s_user,
            AMOUNT
        );

        vm.prank(s_user);
        lancaCanonicalBridge.sendToken{value: messageFee}(AMOUNT, dstChainData, ZERO_BYTES);
    }

    function test_sendToken_WithContractCall_Success() public {
        bytes memory callData = abi.encode("test data");
        bytes memory dstChainData = MessageCodec.encodeEvmDstChainData(
            address(s_lancaBridgeMock),
            GAS_LIMIT
        );
        uint256 messageFee = lancaCanonicalBridge.getBridgeNativeFee(
            ZERO_AMOUNT,
            SRC_CHAIN_SELECTOR,
            dstChainData,
            callData
        );

        _approveBridge(AMOUNT);

        vm.prank(s_user);
        lancaCanonicalBridge.sendToken{value: messageFee}(AMOUNT, dstChainData, callData);
    }

    function test_sendToken_RevertsOnReentrancyAttack() public {
        MaliciousToken maliciousToken = new MaliciousToken();

        LancaCanonicalBridge newBridge = new LancaCanonicalBridge(
            SRC_CHAIN_SELECTOR,
            address(s_conceroRouter),
            address(maliciousToken),
            address(s_lancaBridgeL1Mock),
            address(s_deployer)
        );

        vm.startPrank(s_deployer);
        newBridge.setRateLimit(SRC_CHAIN_SELECTOR, MAX_RATE_AMOUNT, REFILL_SPEED, true);
        newBridge.setRateLimit(SRC_CHAIN_SELECTOR, MAX_RATE_AMOUNT, REFILL_SPEED, false);
        vm.stopPrank();

        maliciousToken.setMinter(address(newBridge));
        maliciousToken.mintTo(s_user, AMOUNT * 2);

        vm.deal(s_user, 1e18);

        bytes memory dstChainData = MessageCodec.encodeEvmDstChainData(
            address(s_lancaBridgeMock),
            0
        );

        uint256 messageFee = newBridge.getBridgeNativeFee(
            ZERO_AMOUNT,
            SRC_CHAIN_SELECTOR,
            dstChainData,
            ZERO_BYTES
        );

        maliciousToken.setAttackMode(true, address(newBridge));

        vm.prank(s_user);
        maliciousToken.approve(address(newBridge), AMOUNT);

        vm.expectRevert(
            abi.encodeWithSelector(ReentrancyGuard.ReentrancyGuardReentrantCall.selector)
        );

        vm.prank(s_user);
        newBridge.sendToken{value: messageFee}(AMOUNT, dstChainData, ZERO_BYTES);
    }

    function test_sendToken_RevertsInvalidDstGasLimitOrCallData() public {
        uint256 messageFee = _getMessageFee();

        _approveBridge(AMOUNT);
        bytes memory nonZeroBytes = "0x01";

        vm.expectRevert(
            abi.encodeWithSelector(LancaCanonicalBridgeBase.InvalidDstGasLimitOrCallData.selector)
        );

        vm.prank(s_user);
        lancaCanonicalBridge.sendToken{value: messageFee}(
            AMOUNT,
            MessageCodec.encodeEvmDstChainData(address(s_lancaBridgeMock), 0),
            nonZeroBytes
        );

        vm.expectRevert(
            abi.encodeWithSelector(LancaCanonicalBridgeBase.InvalidDstGasLimitOrCallData.selector)
        );

        vm.prank(s_user);
        lancaCanonicalBridge.sendToken{value: messageFee}(
            AMOUNT,
            MessageCodec.encodeEvmDstChainData(address(s_lancaBridgeMock), GAS_LIMIT),
            ZERO_BYTES
        );
    }
}
