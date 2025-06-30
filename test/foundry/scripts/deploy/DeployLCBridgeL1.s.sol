// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {LancaCanonicalBridgeL1} from "contracts/LancaCanonicalBridge/LancaCanonicalBridgeL1.sol";
import {TransparentUpgradeableProxy, ITransparentUpgradeableProxy} from "contracts/Proxy/TransparentUpgradeableProxy.sol";
import {LCBridgeL1BaseTest} from "test/foundry/LCBridgeL1/base/LCBridgeL1BaseTest.sol";

contract DeployLCBridgeL1 is LCBridgeL1BaseTest {
    TransparentUpgradeableProxy internal lancaCanonicalBridgeL1Proxy;
    LancaCanonicalBridgeL1 internal lancaCanonicalBridgeL1;

    function setUp() public virtual override {
        super.setUp();
    }

    function setProxyImplementation(address implementation) public {
        vm.startPrank(proxyDeployer);
        ITransparentUpgradeableProxy(address(lancaCanonicalBridgeL1Proxy)).upgradeToAndCall(
            implementation,
            bytes("")
        );
        vm.stopPrank();
    }

    function deploy() public returns (address) {
        address implementation = _deployImplementation(conceroRouter, usdc);
        _deployProxy(implementation);

        return address(lancaCanonicalBridgeL1Proxy);
    }

    function deploy(address _conceroRouter, address _usdc) public returns (address) {
        address implementation = _deployImplementation(_conceroRouter, _usdc);
        _deployProxy(implementation);
        return address(lancaCanonicalBridgeL1Proxy);
    }

    function _deployProxy(address implementation) internal {
        vm.startPrank(proxyDeployer);
        lancaCanonicalBridgeL1Proxy = new TransparentUpgradeableProxy(
            implementation,
            proxyDeployer,
            ""
        );
        vm.stopPrank();
    }

    function _deployImplementation(
        address _conceroRouter,
        address _usdc
    ) internal returns (address) {
        vm.startPrank(deployer);

        lancaCanonicalBridgeL1 = new LancaCanonicalBridgeL1(_conceroRouter, _usdc);
        vm.stopPrank();

        return address(lancaCanonicalBridgeL1);
    }
}
