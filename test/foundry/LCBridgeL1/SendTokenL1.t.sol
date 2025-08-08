// SPDX-License-Identifier: UNLICENSED
/* solhint-disable func-name-mixedcase */
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {CommonErrors} from "@concero/v2-contracts/contracts/common/CommonErrors.sol";

import {LCBridgeL1Test} from "./base/LCBridgeL1Test.sol";
import {MaliciousPool} from "../mocks/MaliciousPool.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";
import {LancaCanonicalBridgeBase} from "contracts/LancaCanonicalBridge/LancaCanonicalBridgeBase.sol";
import {LancaCanonicalBridgeL1} from "contracts/LancaCanonicalBridge/LancaCanonicalBridgeL1.sol";

contract SendTokenL1Test is LCBridgeL1Test {
    function setUp() public override {
        super.setUp();
    }

    function test_sendToken_RevertsInvalidAmount() public {
        vm.expectRevert(abi.encodeWithSelector(CommonErrors.InvalidAmount.selector));

        lancaCanonicalBridgeL1.sendToken(
            user,
            ZERO_AMOUNT,
            DST_CHAIN_SELECTOR,
            ZERO_AMOUNT,
            ZERO_BYTES
        );
    }

    function test_sendToken_RevertsPoolNotFound() public {
        vm.expectRevert(
            abi.encodeWithSelector(LancaCanonicalBridgeL1.PoolNotFound.selector, DST_CHAIN_SELECTOR)
        );

        lancaCanonicalBridgeL1.sendToken(user, AMOUNT, DST_CHAIN_SELECTOR, ZERO_AMOUNT, ZERO_BYTES);
    }

    function test_sendToken_RevertsInvalidDstBridgeIfDstBridgeNotSet() public {
        _addDefaultPool();

        vm.expectRevert(abi.encodeWithSelector(LancaCanonicalBridgeL1.InvalidDstBridge.selector));

        lancaCanonicalBridgeL1.sendToken(user, AMOUNT, DST_CHAIN_SELECTOR, ZERO_AMOUNT, ZERO_BYTES);
    }

    function test_sendToken_Success() public {
        _addDefaultPool();
        _addDefaultDstBridge();

        uint256 messageFee = _getMessageFee();

        _approvePool(AMOUNT);

        bytes memory message = _encodeBridgeParams(user, user, AMOUNT, ZERO_AMOUNT, ZERO_BYTES);
        bytes32 expectedMessageId = _getMessageId(DST_CHAIN_SELECTOR, false, address(0), message);

        vm.prank(user);
        bytes32 messageId = lancaCanonicalBridgeL1.sendToken{value: messageFee}(
            user,
            AMOUNT,
            DST_CHAIN_SELECTOR,
            ZERO_AMOUNT,
            ZERO_BYTES
        );

        assertEq(messageId, expectedMessageId);
        assertEq(MockUSDC(usdc).balanceOf(address(lancaCanonicalBridgePool)), AMOUNT);
    }

    function test_sendToken_WithContractCall() public {
        _addDefaultPool();
        _addDefaultDstBridge();

        uint256 messageFee = lancaCanonicalBridgeL1.getBridgeNativeFee(
            DST_CHAIN_SELECTOR,
            address(lancaBridgeMock),
            GAS_LIMIT
        );

        _approvePool(AMOUNT);

        bytes memory message = _encodeBridgeParams(
            user,
            user,
            AMOUNT,
            GAS_LIMIT,
            abi.encode("test")
        );
        bytes32 expectedMessageId = _getMessageId(DST_CHAIN_SELECTOR, false, address(0), message);

        vm.prank(user);
        bytes32 messageId = lancaCanonicalBridgeL1.sendToken{value: messageFee}(
            user,
            AMOUNT,
            DST_CHAIN_SELECTOR,
            GAS_LIMIT,
            abi.encode("test")
        );

        assertEq(messageId, expectedMessageId);
        assertEq(MockUSDC(usdc).balanceOf(address(lancaCanonicalBridgePool)), AMOUNT);
    }

    function test_sendToken_EmitsTokenSent() public {
        _addDefaultPool();
        _addDefaultDstBridge();

        uint256 messageFee = _getMessageFee();

        _approvePool(AMOUNT);

        bytes memory message = _encodeBridgeParams(user, user, AMOUNT, ZERO_AMOUNT, ZERO_BYTES);
        bytes32 messageId = _getMessageId(DST_CHAIN_SELECTOR, false, address(0), message);

        vm.expectEmit(true, true, true, true);
        emit LancaCanonicalBridgeBase.TokenSent(messageId, user, user, AMOUNT);

        vm.prank(user);
        lancaCanonicalBridgeL1.sendToken{value: messageFee}(
            user,
            AMOUNT,
            DST_CHAIN_SELECTOR,
            ZERO_AMOUNT,
            ZERO_BYTES
        );
    }

    function test_sendToken_EmitsSentToDestinationBridge() public {
        _addDefaultPool();
        _addDefaultDstBridge();

        uint256 messageFee = _getMessageFee();

        _approvePool(AMOUNT);

        bytes memory message = _encodeBridgeParams(user, user, AMOUNT, ZERO_AMOUNT, ZERO_BYTES);
        bytes32 messageId = _getMessageId(DST_CHAIN_SELECTOR, false, address(0), message);

        vm.expectEmit(true, true, true, true);
        emit LancaCanonicalBridgeBase.SentToDestinationBridge(
            messageId,
            DST_CHAIN_SELECTOR,
            lancaBridgeMock
        );

        vm.prank(user);
        lancaCanonicalBridgeL1.sendToken{value: messageFee}(
            user,
            AMOUNT,
            DST_CHAIN_SELECTOR,
            ZERO_AMOUNT,
            ZERO_BYTES
        );
    }

    // TODO: check this test
    function test_sendToken_WithReceiverCallData() public {
        _addDefaultPool();
        _addDefaultDstBridge();

        uint256 messageFee = lancaCanonicalBridgeL1.getBridgeNativeFee(
            DST_CHAIN_SELECTOR,
            address(lancaBridgeMock),
            GAS_LIMIT
        );

        _approvePool(AMOUNT);

        address tokenReceiver = makeAddr("tokenReceiver");
        bytes memory receiverData = abi.encodeCall(ERC20.transfer, (tokenReceiver, AMOUNT));

        vm.prank(user);
        lancaCanonicalBridgeL1.sendToken{value: messageFee}(
            tokenReceiver,
            AMOUNT,
            DST_CHAIN_SELECTOR,
            GAS_LIMIT,
            receiverData
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

        vm.prank(deployer);
        lancaCanonicalBridgeL1.addPools(dstChainSelectors, pools);

        uint24[] memory dstChainSelectors2 = new uint24[](1);
        dstChainSelectors2[0] = attackChainSelector;
        address[] memory dstBridges = new address[](1);
        dstBridges[0] = lancaBridgeMock;

        vm.prank(deployer);
        lancaCanonicalBridgeL1.addDstBridges(dstChainSelectors2, dstBridges);

        vm.prank(deployer);
        lancaCanonicalBridgeL1.setRateLimit(
            attackChainSelector,
            MAX_RATE_AMOUNT,
            REFILL_SPEED,
            true
        );

        uint256 messageFee = _getMessageFee();

        vm.expectRevert(abi.encodeWithSelector(ReentrancyGuard.ReentrancyGuardReentrantCall.selector));

        vm.prank(user);
        lancaCanonicalBridgeL1.sendToken{value: messageFee}(
            user,
            AMOUNT,
            attackChainSelector,
            ZERO_AMOUNT,
            ZERO_BYTES
        );
    }
}
