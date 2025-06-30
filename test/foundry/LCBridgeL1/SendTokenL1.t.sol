// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {CommonErrors} from "@concero/messaging-contracts-v2/contracts/common/CommonErrors.sol";
import {ConceroTypes} from "@concero/messaging-contracts-v2/contracts/ConceroClient/ConceroTypes.sol";
import {IConceroClientErrors} from "@concero/messaging-contracts-v2/contracts/interfaces/IConceroClientErrors.sol";

import {LCBridgeL1Test} from "./base/LCBridgeL1Test.sol";
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
            0,
            DST_CHAIN_SELECTOR,
            address(0),
            ConceroTypes.EvmDstChainData({receiver: lancaBridgeMock, gasLimit: GAS_LIMIT})
        );
    }

    function test_sendToken_RevertsPoolNotFound() public {
        vm.expectRevert(
            abi.encodeWithSelector(LancaCanonicalBridgeL1.PoolNotFound.selector, DST_CHAIN_SELECTOR)
        );

        lancaCanonicalBridgeL1.sendToken(
            AMOUNT,
            DST_CHAIN_SELECTOR,
            address(0),
            ConceroTypes.EvmDstChainData({receiver: lancaBridgeMock, gasLimit: GAS_LIMIT})
        );
    }

    function test_sendToken_RevertsInvalidLaneIfLaneNotSet() public {
        _addDefaultPool();

        vm.expectRevert(abi.encodeWithSelector(LancaCanonicalBridgeL1.InvalidLane.selector));

        lancaCanonicalBridgeL1.sendToken(
            AMOUNT,
            DST_CHAIN_SELECTOR,
            address(0),
            ConceroTypes.EvmDstChainData({receiver: lancaBridgeMock, gasLimit: GAS_LIMIT})
        );
    }

    function test_sendToken_RevertsInvalidLaneIfReceiverNotLane() public {
        _addDefaultPool();
        _addDefaultLane();

        vm.expectRevert(abi.encodeWithSelector(LancaCanonicalBridgeL1.InvalidLane.selector));

        lancaCanonicalBridgeL1.sendToken(
            AMOUNT,
            DST_CHAIN_SELECTOR,
            address(0),
            ConceroTypes.EvmDstChainData({receiver: address(0), gasLimit: GAS_LIMIT})
        );
    }

    function test_sendToken_RevertsInsufficientFee() public {
        _addDefaultPool();
        _addDefaultLane();

        uint256 messageFee = lancaCanonicalBridgeL1.getMessageFee(
            DST_CHAIN_SELECTOR,
            address(0),
            ConceroTypes.EvmDstChainData({receiver: lancaBridgeMock, gasLimit: GAS_LIMIT})
        );

        vm.expectRevert(
            abi.encodeWithSelector(IConceroClientErrors.InsufficientFee.selector, 0, messageFee)
        );

        lancaCanonicalBridgeL1.sendToken(
            AMOUNT,
            DST_CHAIN_SELECTOR,
            address(0),
            ConceroTypes.EvmDstChainData({receiver: lancaBridgeMock, gasLimit: GAS_LIMIT})
        );
    }

    function test_sendToken_RevertsTransferFailed() public {
        _addDefaultPool();
        _addDefaultLane();

        uint256 messageFee = lancaCanonicalBridgeL1.getMessageFee(
            DST_CHAIN_SELECTOR,
            address(0),
            ConceroTypes.EvmDstChainData({receiver: lancaBridgeMock, gasLimit: GAS_LIMIT})
        );

        _approvePool(AMOUNT);
        MockUSDC(usdc).setShouldFailTransfer(true);

        vm.expectRevert(abi.encodeWithSelector(CommonErrors.TransferFailed.selector));

        vm.prank(user);
        lancaCanonicalBridgeL1.sendToken{value: messageFee}(
            AMOUNT,
            DST_CHAIN_SELECTOR,
            address(0),
            ConceroTypes.EvmDstChainData({receiver: lancaBridgeMock, gasLimit: GAS_LIMIT})
        );
    }

    function test_sendToken_Success() public {
        _addDefaultPool();
        _addDefaultLane();

        uint256 messageFee = lancaCanonicalBridgeL1.getMessageFee(
            DST_CHAIN_SELECTOR,
            address(0),
            ConceroTypes.EvmDstChainData({receiver: lancaBridgeMock, gasLimit: GAS_LIMIT})
        );

        _approvePool(AMOUNT);

        vm.prank(user);
        bytes32 messageId = lancaCanonicalBridgeL1.sendToken{value: messageFee}(
            AMOUNT,
            DST_CHAIN_SELECTOR,
            address(0),
            ConceroTypes.EvmDstChainData({receiver: lancaBridgeMock, gasLimit: GAS_LIMIT})
        );

        assertEq(messageId, DEFAULT_MESSAGE_ID);
        assertEq(MockUSDC(usdc).balanceOf(address(lancaCanonicalBridgePool)), AMOUNT);
    }

    function test_sendToken_EmitsTokenSent() public {
        _addDefaultPool();
        _addDefaultLane();

        uint256 messageFee = lancaCanonicalBridgeL1.getMessageFee(
            DST_CHAIN_SELECTOR,
            address(0),
            ConceroTypes.EvmDstChainData({receiver: lancaBridgeMock, gasLimit: GAS_LIMIT})
        );

        _approvePool(AMOUNT);

        vm.expectEmit(true, true, true, true);
        emit LancaCanonicalBridgeBase.TokenSent(
            DEFAULT_MESSAGE_ID,
            lancaBridgeMock,
            DST_CHAIN_SELECTOR,
            user,
            AMOUNT,
            messageFee
        );

        vm.prank(user);
        lancaCanonicalBridgeL1.sendToken{value: messageFee}(
            AMOUNT,
            DST_CHAIN_SELECTOR,
            address(0),
            ConceroTypes.EvmDstChainData({receiver: lancaBridgeMock, gasLimit: GAS_LIMIT})
        );
    }

    function test_sendToken_RevertsOnReentrancyAttack() public {
        MaliciousPool maliciousPool = new MaliciousPool(
            usdc,
            address(lancaCanonicalBridgeL1),
            DST_CHAIN_SELECTOR,
            lancaBridgeMock
        );

        uint24[] memory dstChainSelectors = new uint24[](1);
        dstChainSelectors[0] = DST_CHAIN_SELECTOR;
        address[] memory pools = new address[](1);
        pools[0] = address(maliciousPool);

        vm.prank(deployer);
        lancaCanonicalBridgeL1.addPools(dstChainSelectors, pools);

        _addDefaultLane();

        vm.deal(address(maliciousPool), 1 ether);

        uint256 messageFee = lancaCanonicalBridgeL1.getMessageFee(
            DST_CHAIN_SELECTOR,
            address(0),
            ConceroTypes.EvmDstChainData({receiver: lancaBridgeMock, gasLimit: GAS_LIMIT})
        );

        vm.prank(user);
        MockUSDC(usdc).approve(address(maliciousPool), AMOUNT * 2);

        maliciousPool.setAttackMode(true);

        vm.expectRevert(abi.encodeWithSelector(ReentrancyGuard.ReentrantCall.selector));

        vm.prank(user);
        lancaCanonicalBridgeL1.sendToken{value: messageFee}(
            AMOUNT,
            DST_CHAIN_SELECTOR,
            address(0),
            ConceroTypes.EvmDstChainData({receiver: lancaBridgeMock, gasLimit: GAS_LIMIT})
        );
    }
}
