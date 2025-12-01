// SPDX-License-Identifier: UNLICENSED
/* solhint-disable func-name-mixedcase */
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {ReentrancyGuard} from "@openzeppelin/contracts-v5/utils/ReentrancyGuard.sol";
import {ERC20} from "@openzeppelin/contracts-v5/token/ERC20/ERC20.sol";

import {MessageCodec} from "@concero/v2-contracts/contracts/common/libraries/MessageCodec.sol";
import {CommonErrors} from "@concero/v2-contracts/contracts/common/CommonErrors.sol";

import {LancaCanonicalBridgeBase} from "contracts/LancaCanonicalBridge/LancaCanonicalBridgeBase.sol";
import {LancaCanonicalBridgeL1} from "contracts/LancaCanonicalBridge/LancaCanonicalBridgeL1.sol";
import {BridgeCodec} from "contracts/common/libraries/BridgeCodec.sol";

import {MaliciousPool} from "../mocks/MaliciousPool.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";
import {LCBridgeL1Base} from "./LCBridgeL1Base.sol";

contract SendTokenL1Test is LCBridgeL1Base {
    function setUp() public override {
        super.setUp();
    }

    function test_sendToken_Success() public {
        _addDefaultPool();
        _addDefaultDstBridge();

        uint256 messageFee = _getMessageFee();

        _approvePool(AMOUNT);

        vm.prank(s_user);
        lancaCanonicalBridgeL1.sendToken{value: messageFee}(
            AMOUNT,
            DST_CHAIN_SELECTOR,
            MessageCodec.encodeEvmDstChainData(address(s_lancaBridgeMock), 0),
            ZERO_BYTES
        );

        assertEq(s_usdc.balanceOf(address(lancaCanonicalBridgePool)), AMOUNT);
    }

    function test_sendToken_RevertsInvalidAmount() public {
        vm.expectRevert(abi.encodeWithSelector(CommonErrors.InvalidAmount.selector));

        lancaCanonicalBridgeL1.sendToken(
            ZERO_AMOUNT,
            DST_CHAIN_SELECTOR,
            MessageCodec.encodeEvmDstChainData(address(s_lancaBridgeMock), 0),
            ZERO_BYTES
        );
    }

    function test_sendToken_RevertsPoolNotFound() public {
        vm.expectRevert(
            abi.encodeWithSelector(LancaCanonicalBridgeL1.PoolNotFound.selector, DST_CHAIN_SELECTOR)
        );

        lancaCanonicalBridgeL1.sendToken(
            AMOUNT,
            DST_CHAIN_SELECTOR,
            MessageCodec.encodeEvmDstChainData(address(s_lancaBridgeMock), 0),
            ZERO_BYTES
        );
    }

    function test_sendToken_RevertsInvalidDstBridgeIfDstBridgeNotSet() public {
        _addDefaultPool();

        vm.expectRevert(abi.encodeWithSelector(LancaCanonicalBridgeL1.InvalidDstBridge.selector));

        lancaCanonicalBridgeL1.sendToken(
            AMOUNT,
            DST_CHAIN_SELECTOR,
            MessageCodec.encodeEvmDstChainData(address(s_lancaBridgeMock), 0),
            ZERO_BYTES
        );
    }

    function test_sendToken_WithContractCall() public {
        _addDefaultPool();
        _addDefaultDstBridge();

        bytes memory payload = abi.encode("test");

        bytes memory dstChainData = MessageCodec.encodeEvmDstChainData(
            address(s_lancaBridgeMock),
            GAS_LIMIT
        );

        uint256 messageFee = lancaCanonicalBridgeL1.getBridgeNativeFee(
            ZERO_AMOUNT,
            DST_CHAIN_SELECTOR,
            dstChainData,
            payload
        );

        _approvePool(AMOUNT);

        vm.prank(s_user);
        lancaCanonicalBridgeL1.sendToken{value: messageFee}(
            AMOUNT,
            DST_CHAIN_SELECTOR,
            dstChainData,
            payload
        );

        assertEq(s_usdc.balanceOf(address(lancaCanonicalBridgePool)), AMOUNT);
    }

    function test_sendToken_EmitsTokenSent() public {
        _addDefaultPool();
        _addDefaultDstBridge();

        uint256 messageFee = _getMessageFee();

        _approvePool(AMOUNT);

        bytes memory dstChainData = MessageCodec.encodeEvmDstChainData(
            address(s_lancaBridgeMock),
            0
        );

        vm.expectEmit(false, true, true, true);
        emit LancaCanonicalBridgeBase.TokenSent(
            DEFAULT_MESSAGE_ID,
            DST_CHAIN_SELECTOR,
            dstChainData,
            s_user,
            AMOUNT
        );

        vm.prank(s_user);
        lancaCanonicalBridgeL1.sendToken{value: messageFee}(
            AMOUNT,
            DST_CHAIN_SELECTOR,
            dstChainData,
            ZERO_BYTES
        );
    }
}
