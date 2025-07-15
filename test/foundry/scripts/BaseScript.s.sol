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
import {DeployMockUSDCe} from "./deploy/DeployMockUSDCe.s.sol";
import {DeployMockConceroRouter} from "./deploy/DeployMockConceroRouter.s.sol";

import {LCBridgeCallData} from "contracts/LancaCanonicalBridge/LancaCanonicalBridgeBase.sol";

abstract contract BaseScript is Script {
    address public immutable deployer;
    address public immutable proxyDeployer;

    address public constant user = address(0x0101010101010101010101010101010101010101);
    address public usdc;
    address public usdcE;
    address public conceroRouter;
    address public lancaBridgeL1Mock = address(0x0202020202020202020202020202020202020202);
    address public lancaBridgeMock = address(0x0303030303030303030303030303030303030303);

    bytes32 public constant DEFAULT_MESSAGE_ID = bytes32(uint256(1));

    bytes public constant ZERO_BYTES = "";
    uint256 public constant ZERO_AMOUNT = 0;

    uint24 public constant SRC_CHAIN_SELECTOR = 1;
    uint24 public constant DST_CHAIN_SELECTOR = 8453;

    uint256 public constant AMOUNT = 1e6;
    uint256 public constant GAS_LIMIT = 150_000;

    uint128 public constant MAX_RATE_AMOUNT = 1000e6; // 1000 USDC max available volume
    uint128 public constant REFILL_SPEED = 10e6; // 10 USDC/sec refill speed

    constructor() {
        deployer = vm.envAddress("DEPLOYER_ADDRESS");
        proxyDeployer = vm.envAddress("PROXY_DEPLOYER_ADDRESS");
    }

    function setUp() public virtual {
        usdc = address(new DeployMockUSDC().deployUSDC("USD Coin", "USDC", 6));
        usdcE = address(new DeployMockUSDCe().deployUSDCe("USD Coin", "USDCe", 6));
        conceroRouter = address(new DeployMockConceroRouter().deployConceroRouter());
    }
}
