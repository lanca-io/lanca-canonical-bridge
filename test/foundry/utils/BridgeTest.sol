// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {Test} from "forge-std/src/Test.sol";

import {BaseScript} from "../scripts/BaseScript.s.sol";
import {IConceroRouter} from "@concero/messaging-contracts-v2/contracts/interfaces/IConceroRouter.sol";

abstract contract BridgeTest is BaseScript, Test {
    function setUp() public virtual override {
        super.setUp();
    }
}
