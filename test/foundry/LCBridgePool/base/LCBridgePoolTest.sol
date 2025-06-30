// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {LancaCanonicalBridgePool} from "contracts/LancaCanonicalBridgePool/LancaCanonicalBridgePool.sol";

import {MockUSDC} from "../../mocks/MockUSDC.sol";
import {BridgeTest} from "../../utils/BridgeTest.sol";
import {DeployLCBridgePool} from "../../scripts/deploy/DeployLCBridgePool.s.sol";

abstract contract LCBridgePoolTest is DeployLCBridgePool, BridgeTest {
    function setUp() public virtual override(DeployLCBridgePool, BridgeTest) {
        super.setUp();

        lancaCanonicalBridgePool = LancaCanonicalBridgePool(
            deploy(usdc, deployer, DST_CHAIN_SELECTOR)
        );
    }

    function _approvePool(uint256 amount) internal {
        vm.prank(deployer);
        MockUSDC(usdc).approve(address(lancaCanonicalBridgePool), amount);
    }
}
