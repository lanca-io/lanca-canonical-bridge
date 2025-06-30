// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {LancaCanonicalBridge} from "contracts/LancaCanonicalBridge/LancaCanonicalBridge.sol";

import {BridgeTest} from "../../utils/BridgeTest.sol";
import {DeployLancaCanonicalBridge} from "../../scripts/deploy/DeployLancaCanonicalBridge.s.sol";

abstract contract LancaCanonicalBridgeTest is DeployLancaCanonicalBridge, BridgeTest {
    function setUp() public virtual override(DeployLancaCanonicalBridge, BridgeTest) {
        super.setUp();

		lancaCanonicalBridge = LancaCanonicalBridge(deploy());
    }
}
