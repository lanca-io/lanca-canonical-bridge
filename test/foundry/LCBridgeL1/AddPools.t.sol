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

contract AddPoolsTest is LCBridgeL1Test {
    function setUp() public override {
        super.setUp();
    }

    function test_addPools_Unauthorized() public {
        uint24[] memory dstChainSelectors = new uint24[](1);
        address[] memory pools = new address[](1);
        pools[0] = address(0);

        vm.expectRevert(CommonErrors.Unauthorized.selector);

        lancaCanonicalBridgeL1.addPools(dstChainSelectors, pools);
    }

    function test_addPools_RevertLengthMismatch() public {
        uint24[] memory dstChainSelectors = new uint24[](1);
        address[] memory pools = new address[](2);

        vm.expectRevert(CommonErrors.LengthMismatch.selector);

        vm.prank(deployer);
        lancaCanonicalBridgeL1.addPools(dstChainSelectors, pools);
    }

    function test_addPools_RevertPoolAlreadyExists() public {
        uint24[] memory dstChainSelectors = new uint24[](1);
        dstChainSelectors[0] = DST_CHAIN_SELECTOR;
        address[] memory pools = new address[](1);
        pools[0] = makeAddr("pool");

        vm.prank(deployer);
        lancaCanonicalBridgeL1.addPools(dstChainSelectors, pools);

        vm.expectRevert(
            abi.encodeWithSelector(
                LancaCanonicalBridgeL1.PoolAlreadyExists.selector,
                DST_CHAIN_SELECTOR
            )
        );

        vm.prank(deployer);
        lancaCanonicalBridgeL1.addPools(dstChainSelectors, pools);
    }

    function test_addPools_Success() public {
        uint24[] memory dstChainSelectors = new uint24[](1);
        dstChainSelectors[0] = DST_CHAIN_SELECTOR;
        address[] memory pools = new address[](1);
        pools[0] = makeAddr("pool");

        vm.prank(deployer);
        lancaCanonicalBridgeL1.addPools(dstChainSelectors, pools);

        assertEq(lancaCanonicalBridgeL1.getPool(DST_CHAIN_SELECTOR), pools[0]);
    }

    function test_addPools_MultiplePools() public {
        uint24[] memory dstChainSelectors = new uint24[](3);
        dstChainSelectors[0] = 1;
        dstChainSelectors[1] = 2;
        dstChainSelectors[2] = 3;

        address[] memory pools = new address[](3);
        pools[0] = makeAddr("pool1");
        pools[1] = makeAddr("pool2");
        pools[2] = makeAddr("pool3");

        vm.prank(deployer);
        lancaCanonicalBridgeL1.addPools(dstChainSelectors, pools);

        assertEq(lancaCanonicalBridgeL1.getPool(1), pools[0]);
        assertEq(lancaCanonicalBridgeL1.getPool(2), pools[1]);
        assertEq(lancaCanonicalBridgeL1.getPool(3), pools[2]);
    }
}
