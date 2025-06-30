// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {CommonErrors} from "@concero/messaging-contracts-v2/contracts/common/CommonErrors.sol";

import {LCBridgeL1Test} from "./base/LCBridgeL1Test.sol";
import {LancaCanonicalBridgeL1} from "../../../contracts/LancaCanonicalBridge/LancaCanonicalBridgeL1.sol";

contract AddLanesTest is LCBridgeL1Test {
    function setUp() public override {
        super.setUp();
    }

    function test_addLanes_Unauthorized() public {
        uint24[] memory dstChainSelectors = new uint24[](1);
        address[] memory lanes = new address[](1);
        lanes[0] = address(0);

        vm.expectRevert(CommonErrors.Unauthorized.selector);

        lancaCanonicalBridgeL1.addLanes(dstChainSelectors, lanes);
    }

    function test_addLanes_RevertLengthMismatch() public {
        uint24[] memory dstChainSelectors = new uint24[](1);
        address[] memory lanes = new address[](2);

        vm.expectRevert(CommonErrors.LengthMismatch.selector);

        vm.prank(deployer);
        lancaCanonicalBridgeL1.addLanes(dstChainSelectors, lanes);
    }

    function test_addLanes_RevertLaneAlreadyExists() public {
        uint24[] memory dstChainSelectors = new uint24[](1);
        dstChainSelectors[0] = DST_CHAIN_SELECTOR;
        address[] memory lanes = new address[](1);
        lanes[0] = makeAddr("lane");

        vm.prank(deployer);
        lancaCanonicalBridgeL1.addLanes(dstChainSelectors, lanes);

        vm.expectRevert(
            abi.encodeWithSelector(
                LancaCanonicalBridgeL1.LaneAlreadyExists.selector,
                DST_CHAIN_SELECTOR
            )
        );

        vm.prank(deployer);
        lancaCanonicalBridgeL1.addLanes(dstChainSelectors, lanes);
    }

    function test_addLanes_Success() public {
        uint24[] memory dstChainSelectors = new uint24[](1);
        dstChainSelectors[0] = DST_CHAIN_SELECTOR;
        address[] memory lanes = new address[](1);
        lanes[0] = makeAddr("lane");

        vm.prank(deployer);
        lancaCanonicalBridgeL1.addLanes(dstChainSelectors, lanes);

        assertEq(lancaCanonicalBridgeL1.getLane(DST_CHAIN_SELECTOR), lanes[0]);
    }

    function test_addLanes_MultipleLanes() public {
        uint24[] memory dstChainSelectors = new uint24[](3);
        dstChainSelectors[0] = 1;
        dstChainSelectors[1] = 2;
        dstChainSelectors[2] = 3;

        address[] memory lanes = new address[](3);
        lanes[0] = makeAddr("lane1");
        lanes[1] = makeAddr("lane2");
        lanes[2] = makeAddr("lane3");

        vm.prank(deployer);
        lancaCanonicalBridgeL1.addLanes(dstChainSelectors, lanes);

        assertEq(lancaCanonicalBridgeL1.getLane(1), lanes[0]);
        assertEq(lancaCanonicalBridgeL1.getLane(2), lanes[1]);
        assertEq(lancaCanonicalBridgeL1.getLane(3), lanes[2]);
    }
}
