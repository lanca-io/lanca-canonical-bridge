// SPDX-License-Identifier: UNLICENSED
/* solhint-disable func-name-mixedcase */
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {CommonErrors} from "@concero/v2-contracts/contracts/common/CommonErrors.sol";

import {LCBridgeL1Test} from "./base/LCBridgeL1Test.sol";
import {LancaCanonicalBridgeL1} from "../../../contracts/LancaCanonicalBridge/LancaCanonicalBridgeL1.sol";

contract ManageDstBridgesTest is LCBridgeL1Test {
    function setUp() public override {
        super.setUp();
    }

    function test_addDstBridges_Unauthorized() public {
        uint24[] memory dstChainSelectors = new uint24[](0);
        address[] memory dstBridges = new address[](0);

        vm.expectRevert(CommonErrors.Unauthorized.selector);

        lancaCanonicalBridgeL1.addDstBridges(dstChainSelectors, dstBridges);
    }

    function test_addDstBridges_RevertLengthMismatch() public {
        uint24[] memory dstChainSelectors = new uint24[](1);
        address[] memory dstBridges = new address[](2);

        vm.expectRevert(CommonErrors.LengthMismatch.selector);

        vm.prank(deployer);
        lancaCanonicalBridgeL1.addDstBridges(dstChainSelectors, dstBridges);
    }

    function test_addDstBridges_RevertDstBridgeAlreadyExists() public {
        uint24[] memory dstChainSelectors = new uint24[](1);
        dstChainSelectors[0] = DST_CHAIN_SELECTOR;
        address[] memory dstBridges = new address[](1);
        dstBridges[0] = makeAddr("dstBridge");

        vm.prank(deployer);
        lancaCanonicalBridgeL1.addDstBridges(dstChainSelectors, dstBridges);

        vm.expectRevert(
            abi.encodeWithSelector(
                LancaCanonicalBridgeL1.DstBridgeAlreadyExists.selector,
                DST_CHAIN_SELECTOR
            )
        );

        vm.prank(deployer);
        lancaCanonicalBridgeL1.addDstBridges(dstChainSelectors, dstBridges);
    }

    function test_addDstBridges_Success() public {
        uint24[] memory dstChainSelectors = new uint24[](1);
        dstChainSelectors[0] = DST_CHAIN_SELECTOR;
        address[] memory dstBridges = new address[](1);
        dstBridges[0] = makeAddr("dstBridge");

        vm.prank(deployer);
        lancaCanonicalBridgeL1.addDstBridges(dstChainSelectors, dstBridges);

        assertEq(lancaCanonicalBridgeL1.getBridgeAddress(DST_CHAIN_SELECTOR), dstBridges[0]);
    }

    function test_addDstBridges_MultipleDstBridges() public {
        uint24[] memory dstChainSelectors = new uint24[](3);
        dstChainSelectors[0] = 1;
        dstChainSelectors[1] = 2;
        dstChainSelectors[2] = 3;

        address[] memory dstBridges = new address[](3);
        dstBridges[0] = makeAddr("dstBridge1");
        dstBridges[1] = makeAddr("dstBridge2");
        dstBridges[2] = makeAddr("dstBridge3");

        vm.prank(deployer);
        lancaCanonicalBridgeL1.addDstBridges(dstChainSelectors, dstBridges);

        assertEq(lancaCanonicalBridgeL1.getBridgeAddress(1), dstBridges[0]);
        assertEq(lancaCanonicalBridgeL1.getBridgeAddress(2), dstBridges[1]);
        assertEq(lancaCanonicalBridgeL1.getBridgeAddress(3), dstBridges[2]);
    }

    function test_removeDstBridges_Unauthorized() public {
        uint24[] memory dstChainSelectors = new uint24[](0);

        vm.expectRevert(CommonErrors.Unauthorized.selector);

        lancaCanonicalBridgeL1.removeDstBridges(dstChainSelectors);
    }

    function test_removeDstBridges_Success() public {
        _addDefaultDstBridge();
        assertEq(lancaCanonicalBridgeL1.getBridgeAddress(DST_CHAIN_SELECTOR), lancaBridgeMock);

        uint24[] memory dstChainSelectors = new uint24[](1);
        dstChainSelectors[0] = DST_CHAIN_SELECTOR;

        vm.prank(deployer);
        lancaCanonicalBridgeL1.removeDstBridges(dstChainSelectors);

        assertEq(lancaCanonicalBridgeL1.getBridgeAddress(DST_CHAIN_SELECTOR), address(0));
    }

    function test_removeDstBridges_MultipleDstBridges() public {
        uint24[] memory dstChainSelectors = new uint24[](3);
        dstChainSelectors[0] = 1;
        dstChainSelectors[1] = 2;
        dstChainSelectors[2] = 3;

        address[] memory dstBridges = new address[](3);
        dstBridges[0] = makeAddr("dstBridge1");
        dstBridges[1] = makeAddr("dstBridge2");
        dstBridges[2] = makeAddr("dstBridge3");

        vm.prank(deployer);
        lancaCanonicalBridgeL1.addDstBridges(dstChainSelectors, dstBridges);

        assertEq(lancaCanonicalBridgeL1.getBridgeAddress(1), dstBridges[0]);
        assertEq(lancaCanonicalBridgeL1.getBridgeAddress(2), dstBridges[1]);
        assertEq(lancaCanonicalBridgeL1.getBridgeAddress(3), dstBridges[2]);

        vm.prank(deployer);
        lancaCanonicalBridgeL1.removeDstBridges(dstChainSelectors);

        assertEq(lancaCanonicalBridgeL1.getBridgeAddress(1), address(0));
        assertEq(lancaCanonicalBridgeL1.getBridgeAddress(2), address(0));
        assertEq(lancaCanonicalBridgeL1.getBridgeAddress(3), address(0));
    }
}
