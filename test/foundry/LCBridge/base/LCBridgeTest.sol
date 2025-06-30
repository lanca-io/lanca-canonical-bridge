// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {LancaCanonicalBridge} from "contracts/LancaCanonicalBridge/LancaCanonicalBridge.sol";

import {BridgeTest} from "../../utils/BridgeTest.sol";
import {DeployLCBridge} from "../../scripts/deploy/DeployLCBridge.s.sol";

abstract contract LCBridgeTest is DeployLCBridge, BridgeTest {
    function setUp() public virtual override(DeployLCBridge, BridgeTest) {
        super.setUp();

        lancaCanonicalBridge = LancaCanonicalBridge(deploy());
    }
}
