// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {Test} from "forge-std/src/Test.sol";

import {IERC20} from "@openzeppelin/contracts-v5/token/ERC20/IERC20.sol";

import {BridgeCodec} from "contracts/common/libraries/BridgeCodec.sol";

import {MockUSDC} from "../mocks/MockUSDC.sol";
import {MockUSDCe} from "../mocks/MockUSDCe.sol";
import {ConceroRouterMock} from "../mocks/ConceroRouterMock.sol";

abstract contract BaseTest is Test {
    using BridgeCodec for address;
    using BridgeCodec for bytes32;
    using BridgeCodec for bytes;

    bytes public constant ZERO_BYTES = "";
    uint256 public constant ZERO_AMOUNT = 0;
    uint24 public constant SRC_CHAIN_SELECTOR = 1;
    uint24 public constant DST_CHAIN_SELECTOR = 8453;
    uint256 public constant NONCE = 1;
    uint256 public constant AMOUNT = 1e6;
    uint256 public constant GAS_LIMIT = 150_000;
    uint128 public constant MAX_RATE_AMOUNT = 1000e6; // 1000 USDC max available volume
    uint128 public constant REFILL_SPEED = 10e6; // 10 USDC/sec refill speed
    bytes32 public constant DEFAULT_MESSAGE_ID = bytes32(uint256(1));
    uint8 internal constant USDC_TOKEN_DECIMALS = 6;

    address public s_deployer = vm.envAddress("DEPLOYER_ADDRESS");
    address public s_proxyDeployer = vm.envAddress("PROXY_DEPLOYER_ADDRESS");
    address public s_relayerLib = makeAddr("relayerLib");
    address public s_validatorLib = makeAddr("validatorLib");
    address public s_user = makeAddr("user");
    address public s_lancaBridgeL1Mock = makeAddr("lancaBridgeL1Mock");
    address public s_lancaBridgeMock = makeAddr("lancaBridgeMock");

    bool[] public s_validationChecks = new bool[](1);
    address[] public s_validatorLibs = new address[](1);

    IERC20 public s_usdc = IERC20(new MockUSDC("USD Coin", "USDC", USDC_TOKEN_DECIMALS));
    IERC20 public s_usdcE = IERC20(new MockUSDCe("USD Coin", "USDCe", USDC_TOKEN_DECIMALS));
    address public s_conceroRouter = address(new ConceroRouterMock());

    constructor() {
        s_validationChecks[0] = true;
        s_validatorLibs[0] = s_validatorLib;
    }
}
