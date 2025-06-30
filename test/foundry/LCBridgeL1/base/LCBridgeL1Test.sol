// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {LancaCanonicalBridgeL1} from "contracts/LancaCanonicalBridge/LancaCanonicalBridgeL1.sol";

import {BridgeTest} from "../../utils/BridgeTest.sol";
import {DeployLCBridgeL1} from "../../scripts/deploy/DeployLCBridgeL1.s.sol";

abstract contract LCBridgeL1Test is DeployLCBridgeL1, BridgeTest {
    function setUp() public virtual override(DeployLCBridgeL1, BridgeTest) {
        super.setUp();

        lancaCanonicalBridgeL1 = LancaCanonicalBridgeL1(deploy());
    }
}
