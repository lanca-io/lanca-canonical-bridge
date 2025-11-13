// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {Script} from "forge-std/src/Script.sol";

import {LancaCanonicalBridge} from "contracts/LancaCanonicalBridge/LancaCanonicalBridge.sol";

contract DeployLCBridge is Script {
    address public deployer = vm.envAddress("DEPLOYER_ADDRESS");

    function deploy(
        uint24 dstChainSelector,
        address conceroRouter,
        address usdcE,
        address lancaBridgeL1,
        address rateLimitAdmin
    ) public returns (address) {
        vm.prank(deployer);
        LancaCanonicalBridge lancaCanonicalBridge = new LancaCanonicalBridge(
            dstChainSelector,
            conceroRouter,
            usdcE,
            lancaBridgeL1,
            rateLimitAdmin
        );

        return address(lancaCanonicalBridge);
    }
}
