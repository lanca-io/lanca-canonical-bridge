// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {LancaCanonicalBridge} from "contracts/LancaCanonicalBridge/LancaCanonicalBridge.sol";
import {TransparentUpgradeableProxy, ITransparentUpgradeableProxy} from "contracts/Proxy/TransparentUpgradeableProxy.sol";
import {LancaCanonicalBridgeBaseTest} from "test/foundry/LCBridge/base/LancaCanonicalBridgeBaseTest.sol";

contract DeployLancaCanonicalBridge is LancaCanonicalBridgeBaseTest {
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
        address implementation = _deployImplementation(
            SRC_CHAIN_SELECTOR,
            conceroRouter,
            usdc,
            lancaBridgeL1
        );
        _deployProxy(implementation);
        return address(lancaCanonicalBridgeProxy);
    }

    function deploy(
        uint24 _dstChainSelector,
        address _conceroRouter,
        address _usdc,
        address _lancaBridgeL1
    ) public returns (address) {
        address implementation = _deployImplementation(
            _dstChainSelector,
            _conceroRouter,
            _usdc,
            _lancaBridgeL1
        );
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

    function _deployImplementation(
        uint24 _dstChainSelector,
        address _conceroRouter,
        address _usdc,
        address _lancaBridgeL1
    ) internal returns (address) {
        vm.startPrank(deployer);

        lancaCanonicalBridge = new LancaCanonicalBridge(
            _dstChainSelector,
            _conceroRouter,
            _usdc,
            _lancaBridgeL1
        );
        vm.stopPrank();

        return address(lancaCanonicalBridge);
    }
}
