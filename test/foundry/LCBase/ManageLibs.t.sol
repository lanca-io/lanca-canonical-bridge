// SPDX-License-Identifier: UNLICENSED
/* solhint-disable func-name-mixedcase */
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {CommonErrors} from "@concero/v2-contracts/contracts/common/CommonErrors.sol";

import {ClientStorage as cs} from "@concero/v2-contracts/contracts/ConceroClient/libraries/ClientStorage.sol";

import {LancaCanonicalBridgeBase} from "contracts/LancaCanonicalBridge/LancaCanonicalBridgeBase.sol";
import {Storage as s} from "contracts/LancaCanonicalBridge/libraries/Storage.sol";
import {StringsUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

import {BaseTest} from "../helpers/BaseTest.sol";

contract LancaCanonicalBridgeBaseWrapper is LancaCanonicalBridgeBase {
    using s for s.Base;
    using cs for cs.ConceroClient;

    constructor(
        address usdcAddress,
        address conceroRouter
    ) LancaCanonicalBridgeBase(usdcAddress, conceroRouter) {}

    function _conceroReceive(bytes calldata messageReceipt) internal override {}

    function exposed_relayerLibIsAllowed(address relayerLib) external view returns (bool) {
        return cs.client().isRelayerLibAllowed[relayerLib];
    }

    function exposed_validatorLibIsAllowed(address validatorLib) external view returns (bool) {
        return cs.client().isValidatorAllowed[validatorLib];
    }

    function exposed_getRequiredValidatorsCount() external view returns (uint256) {
        return cs.client().requiredValidatorsCount;
    }
}

contract ManageLibsTest is BaseTest {
    LancaCanonicalBridgeBaseWrapper internal lancaCanonicalBridgeBase;
    function setUp() public {
        vm.prank(s_deployer);
        lancaCanonicalBridgeBase = new LancaCanonicalBridgeBaseWrapper(
            address(s_usdcE),
            s_conceroRouter
        );
        lancaCanonicalBridgeBase.initialize(s_deployer);
    }

    /* ------- setRelayerLib ------- */

    function test_setRelayerLib_Success() public {
        vm.prank(s_deployer);
        lancaCanonicalBridgeBase.setRelayerLib(s_relayerLib);

        assertEq(lancaCanonicalBridgeBase.getRelayerLib(), s_relayerLib);
        assertEq(lancaCanonicalBridgeBase.exposed_relayerLibIsAllowed(s_relayerLib), true);
    }

    function test_setRelayerLib_Unauthorized() public {
        vm.expectRevert(
            _constructAccessControlError(address(this), lancaCanonicalBridgeBase.ADMIN())
        );
        lancaCanonicalBridgeBase.setRelayerLib(s_relayerLib);
    }

    function test_setRelayerLib_RevertsInvalidAddress() public {
        vm.expectRevert(CommonErrors.InvalidAddress.selector);

        vm.prank(s_deployer);
        lancaCanonicalBridgeBase.setRelayerLib(address(0));
    }

    function test_setRelayerLib_RevertsRelayerLibAlreadySet() public {
        vm.prank(s_deployer);
        lancaCanonicalBridgeBase.setRelayerLib(s_relayerLib);

        vm.expectRevert(
            abi.encodeWithSelector(
                LancaCanonicalBridgeBase.RelayerLibAlreadySet.selector,
                s_relayerLib
            )
        );

        vm.prank(s_deployer);
        lancaCanonicalBridgeBase.setRelayerLib(s_relayerLib);
    }

    /* ------- removeRelayerLib ------- */

    function test_removeRelayerLib_Success() public {
        vm.prank(s_deployer);
        lancaCanonicalBridgeBase.setRelayerLib(s_relayerLib);

        vm.prank(s_deployer);
        lancaCanonicalBridgeBase.removeRelayerLib();

        assertEq(lancaCanonicalBridgeBase.getRelayerLib(), address(0));
        assertEq(lancaCanonicalBridgeBase.exposed_relayerLibIsAllowed(s_relayerLib), false);
    }

    function test_removerRelayerLib_RevertsUnauthorized() public {
        vm.expectRevert(
            _constructAccessControlError(address(this), lancaCanonicalBridgeBase.ADMIN())
        );
        lancaCanonicalBridgeBase.removeRelayerLib();
    }

    function test_removeRelayerLib_RevertsRelayerIsNotSet() public {
        vm.expectRevert(LancaCanonicalBridgeBase.RelayerIsNotSet.selector);

        vm.prank(s_deployer);
        lancaCanonicalBridgeBase.removeRelayerLib();
    }

    /* ------- setValidatorLib ------- */

    function test_setValidatorLib_Success() public {
        vm.prank(s_deployer);
        lancaCanonicalBridgeBase.setValidatorLib(s_validatorLib);

        assertEq(lancaCanonicalBridgeBase.getValidatorLib(), s_validatorLib);
        assertEq(lancaCanonicalBridgeBase.exposed_validatorLibIsAllowed(s_validatorLib), true);
        assertEq(lancaCanonicalBridgeBase.exposed_getRequiredValidatorsCount(), 1);
    }

    function test_setValidatorLib_Unauthorized() public {
        vm.expectRevert(
            _constructAccessControlError(address(this), lancaCanonicalBridgeBase.ADMIN())
        );
        lancaCanonicalBridgeBase.setValidatorLib(s_validatorLib);
    }

    function test_setValidatorLib_RevertsInvalidAddress() public {
        vm.expectRevert(CommonErrors.InvalidAddress.selector);

        vm.prank(s_deployer);
        lancaCanonicalBridgeBase.setValidatorLib(address(0));
    }

    function test_setValidatorLib_RevertsValidatorAlreadySet() public {
        vm.prank(s_deployer);
        lancaCanonicalBridgeBase.setValidatorLib(s_validatorLib);

        vm.expectRevert(
            abi.encodeWithSelector(
                LancaCanonicalBridgeBase.ValidatorAlreadySet.selector,
                s_validatorLib
            )
        );

        vm.prank(s_deployer);
        lancaCanonicalBridgeBase.setValidatorLib(s_validatorLib);
    }

    /* ------- removeValidatorLib ------- */

    function test_removeValidatorLib_Success() public {
        vm.prank(s_deployer);
        lancaCanonicalBridgeBase.setValidatorLib(s_validatorLib);

        vm.prank(s_deployer);
        lancaCanonicalBridgeBase.removeValidatorLib();

        assertEq(lancaCanonicalBridgeBase.getValidatorLib(), address(0));
        assertEq(lancaCanonicalBridgeBase.exposed_validatorLibIsAllowed(s_validatorLib), false);
        assertEq(lancaCanonicalBridgeBase.exposed_getRequiredValidatorsCount(), 0);
    }

    function test_removeValidatorLib_RevertsUnauthorized() public {
        vm.expectRevert(
            _constructAccessControlError(address(this), lancaCanonicalBridgeBase.ADMIN())
        );

        lancaCanonicalBridgeBase.removeValidatorLib();
    }

    function test_removeValidatorLib_RevertsValidatorIsNotSet() public {
        vm.expectRevert(LancaCanonicalBridgeBase.ValidatorIsNotSet.selector);

        vm.prank(s_deployer);
        lancaCanonicalBridgeBase.removeValidatorLib();
    }

    function _constructAccessControlError(
        address account,
        bytes32 role
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(uint160(account), 20),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(role), 32)
            );
    }
}
