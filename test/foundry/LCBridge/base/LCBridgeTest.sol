// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {LancaCanonicalBridge} from "contracts/LancaCanonicalBridge/LancaCanonicalBridge.sol";
import {LancaCanonicalBridgeClientExample} from "contracts/LancaCanonicalBridgeClient/LancaCanonicalBridgeClientExample.sol";

import {BridgeTest} from "../../utils/BridgeTest.sol";
import {MockUSDCe} from "../../mocks/MockUSDCe.sol";
import {DeployLCBridge} from "../../scripts/deploy/DeployLCBridge.s.sol";

abstract contract LCBridgeTest is DeployLCBridge, BridgeTest {
    LancaCanonicalBridgeClientExample internal lcBridgeClient;

    function setUp() public virtual override(DeployLCBridge, BridgeTest) {
        super.setUp();

        lancaCanonicalBridge = LancaCanonicalBridge(deploy());
        lcBridgeClient = new LancaCanonicalBridgeClientExample(address(lancaCanonicalBridge));

        MockUSDCe(usdcE).setMinter(address(lancaCanonicalBridge));
        MockUSDCe(usdcE).mintTo(user, AMOUNT);

        vm.deal(user, 1e18);
    }

    function _approveBridge(uint256 amount) internal {
        vm.prank(user);
        MockUSDCe(usdcE).approve(address(lancaCanonicalBridge), amount);
    }
}
