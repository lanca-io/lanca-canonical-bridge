// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {Script} from "forge-std/src/Script.sol";

import {LancaCanonicalBridgeL1} from "contracts/LancaCanonicalBridge/LancaCanonicalBridgeL1.sol";

contract DeployLCBridgeL1 is Script {
    address public deployer = vm.envAddress("DEPLOYER_ADDRESS");

    function deploy(
        address conceroRouter,
        address usdc,
        address rateLimitAdmin
    ) public returns (address) {
        vm.prank(deployer);
        LancaCanonicalBridgeL1 lancaCanonicalBridgeL1 = new LancaCanonicalBridgeL1(
            conceroRouter,
            usdc,
            rateLimitAdmin
        );

        return address(lancaCanonicalBridgeL1);
    }
}
