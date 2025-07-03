// SPDX-License-Identifier: UNLICENSED
/* solhint-disable func-name-mixedcase */
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {CommonErrors} from "@concero/messaging-contracts-v2/contracts/common/CommonErrors.sol";
import {LCBridgePoolTest} from "./base/LCBridgePoolTest.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";

contract LancaCanonicalBridgePoolTest is LCBridgePoolTest {
    function setUp() public override {
        super.setUp();
    }

    function test_deposit_RevertsUnauthorized() public {
        vm.expectRevert(CommonErrors.Unauthorized.selector);

        vm.prank(user);
        lancaCanonicalBridgePool.deposit(user, AMOUNT);
    }

    function test_deposit_Success() public {
        _approvePool(AMOUNT);

        vm.prank(deployer);
        bool success = lancaCanonicalBridgePool.deposit(deployer, AMOUNT);

        assertTrue(success);
        assertEq(MockUSDC(usdc).balanceOf(address(lancaCanonicalBridgePool)), AMOUNT);
    }

    function test_withdraw_RevertsUnauthorized() public {
        vm.expectRevert(CommonErrors.Unauthorized.selector);

        vm.prank(user);
        lancaCanonicalBridgePool.withdraw(user, AMOUNT);
    }

    function test_withdraw_Success() public {
        _approvePool(AMOUNT);

        vm.prank(deployer);
        lancaCanonicalBridgePool.deposit(deployer, AMOUNT);

        uint256 deployerBalanceBefore = MockUSDC(usdc).balanceOf(deployer);

        vm.prank(deployer);
        bool success = lancaCanonicalBridgePool.withdraw(deployer, AMOUNT);

        assertEq(MockUSDC(usdc).balanceOf(deployer), deployerBalanceBefore + AMOUNT);
        assertEq(MockUSDC(usdc).balanceOf(address(lancaCanonicalBridgePool)), 0);
        assertEq(success, true);
    }

    function test_getPoolInfo() public {
        test_deposit_Success();

        (uint24 dstChainSelector, uint256 lockedUSDC) = lancaCanonicalBridgePool.getPoolInfo();

        assertEq(dstChainSelector, DST_CHAIN_SELECTOR);
        assertEq(lockedUSDC, AMOUNT);
    }
}
