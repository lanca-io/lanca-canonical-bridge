// SPDX-License-Identifier: UNLICENSED
/* solhint-disable func-name-mixedcase */
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {CommonErrors} from "@concero/v2-contracts/contracts/common/CommonErrors.sol";
import {LCBridgePoolBase} from "./LCBridgePoolBase.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";

contract LancaCanonicalBridgePoolTest is LCBridgePoolBase {
    function setUp() public override {
        super.setUp();
    }

    function test_deposit_RevertsUnauthorized() public {
        vm.expectRevert(CommonErrors.Unauthorized.selector);

        vm.prank(s_user);
        lancaCanonicalBridgePool.deposit(s_user, AMOUNT);
    }

    function test_deposit_Success() public {
        _approvePool(AMOUNT);

        vm.prank(s_lancaBridgeL1Mock);
        lancaCanonicalBridgePool.deposit(s_deployer, AMOUNT);

        assertEq(s_usdc.balanceOf(address(lancaCanonicalBridgePool)), AMOUNT);
    }

    function test_withdraw_RevertsUnauthorized() public {
        vm.expectRevert(CommonErrors.Unauthorized.selector);

        vm.prank(s_user);
        lancaCanonicalBridgePool.withdraw(s_user, AMOUNT);
    }

    function test_withdraw_Success() public {
        _approvePool(AMOUNT);

        vm.prank(s_lancaBridgeL1Mock);
        lancaCanonicalBridgePool.deposit(s_deployer, AMOUNT);

        uint256 deployerBalanceBefore = s_usdc.balanceOf(s_deployer);

        vm.prank(s_lancaBridgeL1Mock);
        lancaCanonicalBridgePool.withdraw(s_deployer, AMOUNT);

        assertEq(s_usdc.balanceOf(s_deployer), deployerBalanceBefore + AMOUNT);
        assertEq(s_usdc.balanceOf(address(lancaCanonicalBridgePool)), 0);
    }

    function test_getPoolInfo() public {
        test_deposit_Success();

        (uint24 dstChainSelector, uint256 lockedUsdc) = lancaCanonicalBridgePool.getPoolInfo();

        assertEq(dstChainSelector, DST_CHAIN_SELECTOR);
        assertEq(lockedUsdc, AMOUNT);
    }
}
