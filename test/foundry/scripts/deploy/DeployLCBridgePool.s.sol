// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {Script} from "forge-std/src/Script.sol";

import {LancaCanonicalBridgePool} from "contracts/LancaCanonicalBridgePool/LancaCanonicalBridgePool.sol";

contract DeployLCBridgePool is Script {
    address public deployer = vm.envAddress("DEPLOYER_ADDRESS");

    function deploy(
        address usdc,
        address lancaCanonicalBridge,
        uint24 dstChainSelector
    ) public returns (address) {
        vm.prank(deployer);
        LancaCanonicalBridgePool lancaCanonicalBridgePool = new LancaCanonicalBridgePool(
            usdc,
            lancaCanonicalBridge,
            dstChainSelector
        );

        return address(lancaCanonicalBridgePool);
    }
}
