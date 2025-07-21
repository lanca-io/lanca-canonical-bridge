// SPDX-License-Identifier: UNLICENSED
/* solhint-disable func-name-mixedcase */
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {CommonErrors} from "@concero/messaging-contracts-v2/contracts/common/CommonErrors.sol";
import {ConceroTypes} from "@concero/messaging-contracts-v2/contracts/ConceroClient/ConceroTypes.sol";
import {IConceroClientErrors} from "@concero/messaging-contracts-v2/contracts/interfaces/IConceroClientErrors.sol";

import {LCBridgeL1Test} from "./base/LCBridgeL1Test.sol";
import {MockConceroRouter} from "../mocks/MockConceroRouter.sol";
import {MaliciousPool} from "../mocks/MaliciousPool.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";
import {ReentrancyGuard} from "contracts/common/ReentrancyGuard.sol";
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
            false,
            ZERO_AMOUNT,
            ZERO_BYTES
        );
    }

    function test_sendToken_RevertsPoolNotFound() public {
        vm.expectRevert(
            abi.encodeWithSelector(LancaCanonicalBridgeL1.PoolNotFound.selector, DST_CHAIN_SELECTOR)
        );

        lancaCanonicalBridgeL1.sendToken(
            user,
            AMOUNT,
            DST_CHAIN_SELECTOR,
            false,
            ZERO_AMOUNT,
            ZERO_BYTES
        );
    }

    function test_sendToken_RevertsInvalidDstBridgeIfDstBridgeNotSet() public {
        _addDefaultPool();

        vm.expectRevert(abi.encodeWithSelector(LancaCanonicalBridgeL1.InvalidDstBridge.selector));

        lancaCanonicalBridgeL1.sendToken(
            user,
            AMOUNT,
            DST_CHAIN_SELECTOR,
            false,
            ZERO_AMOUNT,
            ZERO_BYTES
        );
    }

    function test_sendToken_Success() public {
        _addDefaultPool();
        _addDefaultDstBridge();

        uint256 messageFee = lancaCanonicalBridgeL1.getMessageFeeForContract(
            DST_CHAIN_SELECTOR,
            address(0),
            ZERO_AMOUNT,
            ZERO_BYTES
        );

        _approvePool(AMOUNT);

        vm.prank(user);
        bytes32 messageId = lancaCanonicalBridgeL1.sendToken{value: messageFee}(
            user,
            AMOUNT,
            DST_CHAIN_SELECTOR,
            false,
            ZERO_AMOUNT,
            ZERO_BYTES
        );

        assertEq(messageId, DEFAULT_MESSAGE_ID);
        assertEq(MockUSDC(usdc).balanceOf(address(lancaCanonicalBridgePool)), AMOUNT);
    }

    function test_sendToken_WithContractCall() public {
        _addDefaultPool();
        _addDefaultDstBridge();

        uint256 messageFee = lancaCanonicalBridgeL1.getMessageFeeForContract(
            DST_CHAIN_SELECTOR,
            address(0),
            GAS_LIMIT,
            abi.encode("test")
        );

        _approvePool(AMOUNT);

        vm.prank(user);
        bytes32 messageId = lancaCanonicalBridgeL1.sendToken{value: messageFee}(
            user,
            AMOUNT,
            DST_CHAIN_SELECTOR,
            true,
            GAS_LIMIT,
            abi.encode("test")
        );

        assertEq(messageId, DEFAULT_MESSAGE_ID);
        assertEq(MockUSDC(usdc).balanceOf(address(lancaCanonicalBridgePool)), AMOUNT);
    }

    function test_sendToken_EmitsTokenSent() public {
        _addDefaultPool();
        _addDefaultDstBridge();

        uint256 messageFee = lancaCanonicalBridgeL1.getMessageFeeForContract(
            DST_CHAIN_SELECTOR,
            address(0),
            ZERO_AMOUNT,
            ZERO_BYTES
        );

        _approvePool(AMOUNT);

        vm.expectEmit(true, true, true, true);
        emit LancaCanonicalBridgeBase.TokenSent(DEFAULT_MESSAGE_ID, user, user, AMOUNT);

        vm.prank(user);
        lancaCanonicalBridgeL1.sendToken{value: messageFee}(
            user,
            AMOUNT,
            DST_CHAIN_SELECTOR,
            false,
            ZERO_AMOUNT,
            ZERO_BYTES
        );
    }

    function test_sendToken_EmitsSentToDestinationBridge() public {
        _addDefaultPool();
        _addDefaultDstBridge();

        uint256 messageFee = lancaCanonicalBridgeL1.getMessageFeeForContract(
            DST_CHAIN_SELECTOR,
            address(0),
            ZERO_AMOUNT,
            ZERO_BYTES
        );

        _approvePool(AMOUNT);

        vm.expectEmit(true, true, true, true);
        emit LancaCanonicalBridgeBase.SentToDestinationBridge(DST_CHAIN_SELECTOR, lancaBridgeMock);

        vm.prank(user);
        lancaCanonicalBridgeL1.sendToken{value: messageFee}(
            user,
            AMOUNT,
            DST_CHAIN_SELECTOR,
            false,
            ZERO_AMOUNT,
            ZERO_BYTES
        );
    }

    function test_sendToken_WithReceiverCallData() public {
        _addDefaultPool();
        _addDefaultDstBridge();

        uint256 messageFee = lancaCanonicalBridgeL1.getMessageFeeForContract(
            DST_CHAIN_SELECTOR,
            address(0),
            ZERO_AMOUNT,
            ZERO_BYTES
        );

        _approvePool(AMOUNT);

        address tokenReceiver = makeAddr("tokenReceiver");
        bytes memory receiverData = abi.encodeCall(ERC20.transfer, (tokenReceiver, AMOUNT));

        vm.prank(user);
        lancaCanonicalBridgeL1.sendToken{value: messageFee}(
            tokenReceiver,
            AMOUNT,
            DST_CHAIN_SELECTOR,
            true,
            GAS_LIMIT,
            receiverData
        );

        assertEq(MockConceroRouter(conceroRouter).s_tokenSender(), user);
        assertEq(MockConceroRouter(conceroRouter).s_tokenReceiver(), tokenReceiver);
        assertEq(MockConceroRouter(conceroRouter).s_tokenAmount(), AMOUNT);
        assertEq(MockConceroRouter(conceroRouter).s_isContract(), 1);
        assertEq(MockConceroRouter(conceroRouter).s_dstCallData(), receiverData);
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

        uint256 messageFee = lancaCanonicalBridgeL1.getMessageFeeForContract(
            attackChainSelector,
            address(0),
            ZERO_AMOUNT,
            ZERO_BYTES
        );

        vm.expectRevert(abi.encodeWithSelector(ReentrancyGuard.ReentrantCall.selector));

        vm.prank(user);
        lancaCanonicalBridgeL1.sendToken{value: messageFee}(
            user,
            AMOUNT,
            attackChainSelector,
            false,
            ZERO_AMOUNT,
            ZERO_BYTES
        );
    }
}
