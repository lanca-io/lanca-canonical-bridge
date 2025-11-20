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
import {LCBridgeL1Base} from "./LCBridgeL1Base.sol";
import {MaliciousPool} from "../mocks/MaliciousPool.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";

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

    function test_sendToken_RevertsOnReentrancyAttack() public {
        uint24 attackChainSelector = 1337; // Use different chain selector

        MaliciousPool maliciousPool = new MaliciousPool();
        maliciousPool.setTarget(address(lancaCanonicalBridgeL1));
        maliciousPool.setAttackMode(true);

        uint24[] memory dstChainSelectors = new uint24[](1);
        dstChainSelectors[0] = attackChainSelector;
        address[] memory pools = new address[](1);
        pools[0] = address(maliciousPool);

        vm.prank(s_deployer);
        lancaCanonicalBridgeL1.addPools(dstChainSelectors, pools);

        uint24[] memory dstChainSelectors2 = new uint24[](1);
        dstChainSelectors2[0] = attackChainSelector;
        bytes32[] memory dstBridges = new bytes32[](1);
        dstBridges[0] = BridgeCodec.toBytes32(s_lancaBridgeMock);

        vm.prank(s_deployer);
        lancaCanonicalBridgeL1.addDstBridges(dstChainSelectors2, dstBridges);

        vm.prank(s_deployer);
        lancaCanonicalBridgeL1.setRateLimit(
            attackChainSelector,
            MAX_RATE_AMOUNT,
            REFILL_SPEED,
            true
        );

        bytes memory dstChainData = MessageCodec.encodeEvmDstChainData(
            address(s_lancaBridgeMock),
            0
        );

        uint256 messageFee = lancaCanonicalBridgeL1.getBridgeNativeFee(
            ZERO_AMOUNT,
            attackChainSelector,
            dstChainData,
            ZERO_BYTES
        );

        vm.expectRevert(
            abi.encodeWithSelector(ReentrancyGuard.ReentrancyGuardReentrantCall.selector)
        );

        vm.prank(s_user);
        lancaCanonicalBridgeL1.sendToken{value: messageFee}(
            AMOUNT,
            attackChainSelector,
            dstChainData,
            ZERO_BYTES
        );
    }
}
