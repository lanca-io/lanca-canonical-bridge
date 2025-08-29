// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {LancaCanonicalBridge} from "contracts/LancaCanonicalBridge/LancaCanonicalBridge.sol";
import {
    LCBTransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "contracts/Proxy/LCBTransparentUpgradeableProxy.sol";
import {LCBridgeBaseTest} from "test/foundry/LCBridge/base/LCBridgeBaseTest.sol";

contract DeployLCBridge is LCBridgeBaseTest {
    LCBTransparentUpgradeableProxy internal lancaCanonicalBridgeProxy;
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
            usdcE,
            lancaBridgeL1Mock,
            deployer
        );
        _deployProxy(implementation);
        return address(lancaCanonicalBridgeProxy);
    }

    function deploy(
        uint24 _dstChainSelector,
        address _conceroRouter,
        address _usdcE,
        address _lancaBridgeL1,
        address _rateLimitAdmin
    ) public returns (address) {
        address implementation = _deployImplementation(
            _dstChainSelector,
            _conceroRouter,
            _usdcE,
            _lancaBridgeL1,
            _rateLimitAdmin
        );
        _deployProxy(implementation);

        return address(lancaCanonicalBridgeProxy);
    }

    function _deployProxy(address implementation) internal {
        vm.startPrank(proxyDeployer);
        lancaCanonicalBridgeProxy = new LCBTransparentUpgradeableProxy(
            implementation,
            proxyDeployer,
            ""
        );
        vm.stopPrank();
    }

    function _deployImplementation(
        uint24 _dstChainSelector,
        address _conceroRouter,
        address _usdcE,
        address _lancaBridgeL1,
        address _rateLimitAdmin
    ) internal returns (address) {
        vm.startPrank(deployer);

        lancaCanonicalBridge = new LancaCanonicalBridge(
            _dstChainSelector,
            _conceroRouter,
            _usdcE,
            _lancaBridgeL1,
            _rateLimitAdmin
        );
        vm.stopPrank();

        return address(lancaCanonicalBridge);
    }
}
