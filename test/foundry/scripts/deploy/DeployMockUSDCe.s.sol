// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {Script} from "forge-std/src/Script.sol";

import {MockUSDCe} from "../../mocks/MockUSDCe.sol";

contract DeployMockUSDCe is Script {
    address public minter = vm.envAddress("DEPLOYER_ADDRESS");

    function deployUSDCe(
        string memory name,
        string memory symbol,
        uint8 decimals
    ) public returns (MockUSDCe) {
        MockUSDCe token = new MockUSDCe(name, symbol, decimals);

        return token;
    }
}
