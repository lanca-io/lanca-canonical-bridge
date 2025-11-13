// SPDX-License-Identifier: UNLICENSED
/* solhint-disable func-name-mixedcase */
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {CommonErrors} from "@concero/v2-contracts/contracts/common/CommonErrors.sol";

import {LCBridgeL1Test} from "./base/LCBridgeL1Test.sol";
import {LancaCanonicalBridgeL1} from "../../../contracts/LancaCanonicalBridge/LancaCanonicalBridgeL1.sol";

contract ManageLibsTest is LCBridgeL1Test {
    function setUp() public override {
        super.setUp();
    }

    function test_setRelayerLib_Unauthorized() public {
        vm.expectRevert(CommonErrors.Unauthorized.selector);

        lancaCanonicalBridgeL1.setRelayerLib(DST_CHAIN_SELECTOR, relayerLib, new bytes(1), true);
    }

    function test_setRelayerLib_Success() public {
        address newRelayerLib = makeAddr("newRelayerLib");
        bytes memory config = new bytes(10);

        vm.prank(deployer);
        lancaCanonicalBridgeL1.setRelayerLib(DST_CHAIN_SELECTOR, newRelayerLib, config, true);
    }

    function test_setValidatorLibs_Unauthorized() public {
        uint24[] memory dstChainSelectors = new uint24[](1);
        LancaCanonicalBridgeL1.ValidatorLibs[]
            memory validatorLibsStruct = new LancaCanonicalBridgeL1.ValidatorLibs[](1);

        vm.expectRevert(CommonErrors.Unauthorized.selector);

        lancaCanonicalBridgeL1.setValidatorLibs(dstChainSelectors, validatorLibsStruct);
    }

    function test_setValidatorLibs_RevertLengthMismatch() public {
        uint24[] memory dstChainSelectors = new uint24[](1);
        LancaCanonicalBridgeL1.ValidatorLibs[]
            memory validatorLibsStruct = new LancaCanonicalBridgeL1.ValidatorLibs[](2);

        vm.expectRevert(CommonErrors.LengthMismatch.selector);

        vm.prank(deployer);
        lancaCanonicalBridgeL1.setValidatorLibs(dstChainSelectors, validatorLibsStruct);
    }

    function test_setValidatorLibs_Success() public {
        uint24[] memory dstChainSelectors = new uint24[](1);
        dstChainSelectors[0] = DST_CHAIN_SELECTOR;

        address[] memory validatorLibs = new address[](1);
        validatorLibs[0] = validatorLib;
        bytes[] memory validatorConfigs = new bytes[](1);
        validatorConfigs[0] = new bytes(0);
        bool[] memory isAllowed = new bool[](1);
        isAllowed[0] = true;

        LancaCanonicalBridgeL1.ValidatorLibs[]
            memory validatorLibsStruct = new LancaCanonicalBridgeL1.ValidatorLibs[](1);
        validatorLibsStruct[0] = LancaCanonicalBridgeL1.ValidatorLibs({
            validatorLibs: validatorLibs,
            validatorConfigs: validatorConfigs,
            isAllowed: isAllowed,
            requiredValidatorsCount: 1
        });

        vm.prank(deployer);
        lancaCanonicalBridgeL1.setValidatorLibs(dstChainSelectors, validatorLibsStruct);
    }
}
