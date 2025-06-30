// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {Script} from "forge-std/src/Script.sol";
import {console} from "forge-std/src/Console.sol";

import {DeployMockUSDC} from "./deploy/DeployMockUSDC.s.sol";
import {DeployMockConceroRouter} from "./deploy/DeployMockConceroRouter.s.sol";

abstract contract BaseScript is Script {
    address public immutable deployer;
    address public immutable proxyDeployer;

    address public constant user = address(0x0101010101010101010101010101010101010101);
    address public usdc;
    address public conceroRouter;
	address public lancaBridgeL1 = address(0x0202020202020202020202020202020202020202);

    uint24 public constant SRC_CHAIN_SELECTOR = 1;
    uint24 public constant DST_CHAIN_SELECTOR = 8453;

    constructor() {
        deployer = vm.envAddress("DEPLOYER_ADDRESS");
        proxyDeployer = vm.envAddress("PROXY_DEPLOYER_ADDRESS");
    }

    function setUp() public virtual {
        usdc = address(new DeployMockUSDC().deployUSDC("USD Coin", "USDC", 6));
        conceroRouter = address(new DeployMockConceroRouter().deployConceroRouter());
    }
}
