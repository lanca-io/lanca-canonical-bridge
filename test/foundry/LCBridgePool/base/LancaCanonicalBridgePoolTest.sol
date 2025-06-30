// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {LancaCanonicalBridgePool} from "contracts/LancaCanonicalBridgePool/LancaCanonicalBridgePool.sol";

import {BridgeTest} from "../../utils/BridgeTest.sol";
import {DeployLancaCanonicalBridgePool} from "../../scripts/deploy/DeployLancaCanonicalBridgePool.s.sol";

abstract contract LancaCanonicalBridgePoolTest is DeployLancaCanonicalBridgePool, BridgeTest {
    function setUp() public virtual override(DeployLancaCanonicalBridgePool, BridgeTest) {
        super.setUp();

        lancaCanonicalBridgePool = LancaCanonicalBridgePool(deploy());
    }
}
