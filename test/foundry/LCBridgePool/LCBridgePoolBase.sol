// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {LancaCanonicalBridgePool} from "contracts/LancaCanonicalBridgePool/LancaCanonicalBridgePool.sol";

import {MockUSDC} from "../mocks/MockUSDC.sol";
import {BaseTest} from "../helpers/BaseTest.sol";

abstract contract LCBridgePoolBase is BaseTest {
    LancaCanonicalBridgePool internal lancaCanonicalBridgePool;

    function setUp() public virtual {
        vm.prank(s_deployer);
        lancaCanonicalBridgePool = new LancaCanonicalBridgePool(
            address(s_usdc),
            s_lancaBridgeL1Mock,
            DST_CHAIN_SELECTOR
        );

        MockUSDC(address(s_usdc)).mint(s_deployer, INITIAL_SUPPLY);
    }

    function _approvePool(uint256 amount) internal {
        vm.prank(s_deployer);
        s_usdc.approve(address(lancaCanonicalBridgePool), amount);
    }
}
