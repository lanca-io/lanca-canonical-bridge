// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {Script} from "forge-std/src/Script.sol";

import {ConceroRouterMock} from "../../mocks/ConceroRouterMock.sol";

contract DeployMockConceroRouter is Script {
    address public deployer = vm.envAddress("DEPLOYER_ADDRESS");

    function deployConceroRouter() public returns (ConceroRouterMock) {
        vm.prank(deployer);
        ConceroRouterMock conceroRouter = new ConceroRouterMock();

        return conceroRouter;
    }
}
