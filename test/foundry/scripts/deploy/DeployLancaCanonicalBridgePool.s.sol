// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {LancaCanonicalBridgePool} from "contracts/LancaCanonicalBridgePool/LancaCanonicalBridgePool.sol";
import {TransparentUpgradeableProxy, ITransparentUpgradeableProxy} from "contracts/Proxy/TransparentUpgradeableProxy.sol";
import {LancaCanonicalBridgePoolBase} from "test/foundry/LCBridgePool/base/LancaCanonicalBridgePoolBase.sol";

contract DeployLancaCanonicalBridgePool is LancaCanonicalBridgePoolBase {
    TransparentUpgradeableProxy internal lancaCanonicalBridgePoolProxy;
    LancaCanonicalBridgePool internal lancaCanonicalBridgePool;

    function setUp() public virtual override {
        super.setUp();
    }

    function setProxyImplementation(address implementation) public {
        vm.startPrank(proxyDeployer);
        ITransparentUpgradeableProxy(address(lancaCanonicalBridgePoolProxy)).upgradeToAndCall(
            implementation,
            bytes("")
        );
        vm.stopPrank();
    }

    function deploy() public returns (address) {
        address implementation = _deployImplementation();
        _deployProxy(implementation);

        return address(lancaCanonicalBridgePoolProxy);
    }

    function deploy() public returns (address) {
        address implementation = _deployImplementation();
        _deployProxy(implementation);
        return address(lancaCanonicalBridgePoolProxy);
    }

    function _deployProxy(address implementation) internal {
        vm.startPrank(proxyDeployer);
        lancaCanonicalBridgePoolProxy = new TransparentUpgradeableProxy(
            implementation,
            proxyDeployer,
            ""
        );
        vm.stopPrank();
    }

    function _deployImplementation() internal returns (address) {
        vm.startPrank(deployer);

        lancaCanonicalBridgePool = new LancaCanonicalBridgePool();
        vm.stopPrank();

        return address(lancaCanonicalBridgePool);
    }
}
