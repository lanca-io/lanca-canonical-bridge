// SPDX-License-Identifier: UNLICENSED
/* solhint-disable func-name-mixedcase */
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {CommonErrors} from "@concero/v2-contracts/contracts/common/CommonErrors.sol";

import {LCBridgeTest} from "./base/LCBridgeTest.sol";
import {LancaCanonicalBridge} from "../../../contracts/LancaCanonicalBridge/LancaCanonicalBridge.sol";

contract ManageLibsTest is LCBridgeTest {
    function setUp() public override {
        super.setUp();
    }

    function test_setRelayerLib_Unauthorized() public {
        vm.expectRevert(CommonErrors.Unauthorized.selector);

        lancaCanonicalBridge.setRelayerLib(relayerLib, new bytes(1), true);
    }

    function test_setRelayerLib_Success() public {
        address newRelayerLib = makeAddr("newRelayerLib");
        bytes memory config = new bytes(10);

        vm.prank(deployer);
        lancaCanonicalBridge.setRelayerLib(newRelayerLib, config, true);
    }

    function test_setValidatorLibs_Unauthorized() public {
        address[] memory validatorLibs = new address[](1);
        bytes[] memory validatorConfigs = new bytes[](1);
        bool[] memory isAllowed = new bool[](1);

        vm.expectRevert(CommonErrors.Unauthorized.selector);

        lancaCanonicalBridge.setValidatorLibs(validatorLibs, validatorConfigs, isAllowed, 1);
    }

    function test_setValidatorLibs_RevertLengthMismatch() public {
        address[] memory validatorLibs = new address[](1);
        bytes[] memory validatorConfigs = new bytes[](2);
        bool[] memory isAllowed = new bool[](1);

        vm.expectRevert(CommonErrors.LengthMismatch.selector);

        vm.prank(deployer);
        lancaCanonicalBridge.setValidatorLibs(validatorLibs, validatorConfigs, isAllowed, 1);
    }

    function test_setValidatorLibs_Success() public {
        address[] memory validatorLibs = new address[](1);
        validatorLibs[0] = validatorLib;
        bytes[] memory validatorConfigs = new bytes[](1);
        validatorConfigs[0] = new bytes(1);
        bool[] memory isAllowed = new bool[](1);
        isAllowed[0] = true;

        vm.prank(deployer);
        lancaCanonicalBridge.setValidatorLibs(validatorLibs, validatorConfigs, isAllowed, 1);
    }
}
