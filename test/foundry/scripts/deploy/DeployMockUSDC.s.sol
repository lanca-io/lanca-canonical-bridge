// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {Script} from "forge-std/src/Script.sol";

import {MockUSDC} from "../../mocks/MockUSDC.sol";

contract DeployMockUSDC is Script {
    address public initialHolder = vm.envAddress("DEPLOYER_ADDRESS");
    uint256 public initialSupply = 1_000_000;

    function deployUSDC(
        string memory name,
        string memory symbol,
        uint8 decimals
    ) public returns (MockUSDC) {
        MockUSDC token = new MockUSDC(name, symbol, decimals);

        token.mint(initialHolder, initialSupply * 10 ** decimals);

        return token;
    }
}
