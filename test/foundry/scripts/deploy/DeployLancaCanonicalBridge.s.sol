// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {LancaCanonicalBridge} from "contracts/LancaCanonicalBridge/LancaCanonicalBridge.sol";
import {TransparentUpgradeableProxy, ITransparentUpgradeableProxy} from "contracts/Proxy/TransparentUpgradeableProxy.sol";
import {LancaCanonicalBridgeBase} from "test/foundry/LCBridge/base/LancaCanonicalBridgeBase.sol";

contract DeployLancaCanonicalBridge is LancaCanonicalBridgeBase {
    TransparentUpgradeableProxy internal lancaCanonicalBridgeProxy;
    LancaCanonicalBridge internal lancaCanonicalBridge;

    function setUp() public virtual override {
        super.setUp();
    }

    function setProxyImplementation(address implementation) public {
        vm.startPrank(proxyDeployer);
        ITransparentUpgradeableProxy(address(lancaCanonicalBridgeProxy)).upgradeToAndCall(
            implementation,
            bytes("")
        );
        vm.stopPrank();
    }

    function deploy() public returns (address) {
        address implementation = _deployImplementation();
        _deployProxy(implementation);

        return address(lancaCanonicalBridgeProxy);
    }

    function deploy() public returns (address) {
        address implementation = _deployImplementation();
        _deployProxy(implementation);
        return address(lancaCanonicalBridgeProxy);
    }

    function _deployProxy(address implementation) internal {
        vm.startPrank(proxyDeployer);
        lancaCanonicalBridgeProxy = new TransparentUpgradeableProxy(
            implementation,
            proxyDeployer,
            ""
        );
        vm.stopPrank();
    }

    function _deployImplementation() internal returns (address) {
        vm.startPrank(deployer);

        lancaCanonicalBridge = new LancaCanonicalBridge();
        vm.stopPrank();

        return address(lancaCanonicalBridge);
    }
}
