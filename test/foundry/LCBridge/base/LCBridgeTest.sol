// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {IConceroRouter} from "@concero/v2-contracts/contracts/interfaces/IConceroRouter.sol";
import {MessageCodec} from "@concero/v2-contracts/contracts/common/libraries/MessageCodec.sol";

import {LancaCanonicalBridge} from "contracts/LancaCanonicalBridge/LancaCanonicalBridge.sol";
import {LancaCanonicalBridgeClientExample} from "contracts/LancaCanonicalBridgeClient/LancaCanonicalBridgeClientExample.sol";

import {MockUSDCe} from "../../mocks/MockUSDCe.sol";
import {DeployLCBridge} from "../../scripts/deploy/DeployLCBridge.s.sol";
import {BaseTest} from "../../utils/BaseTest.sol";

abstract contract LCBridgeTest is BaseTest {
    LancaCanonicalBridge internal lancaCanonicalBridge;
    LancaCanonicalBridgeClientExample internal lcBridgeClient;

    function setUp() public virtual override {
        super.setUp();

        lancaCanonicalBridge = LancaCanonicalBridge(
            (new DeployLCBridge()).deploy(
                SRC_CHAIN_SELECTOR,
                conceroRouter,
                usdcE,
                lancaBridgeL1Mock,
                deployer
            )
        );

        address[] memory validatorLibs = new address[](1);
        validatorLibs[0] = validatorLib;
        bytes[] memory validatorConfigs = new bytes[](1);
        validatorConfigs[0] = new bytes(1);
        bool[] memory isAllowed = new bool[](1);
        isAllowed[0] = true;

        vm.startPrank(deployer);
        lancaCanonicalBridge.setValidatorLibs(validatorLibs, validatorConfigs, isAllowed, 1);
        lancaCanonicalBridge.setRelayerLib(relayerLib, new bytes(1), true);
        vm.stopPrank();

        lcBridgeClient = new LancaCanonicalBridgeClientExample(
            address(lancaCanonicalBridge),
            usdcE
        );

        MockUSDCe(usdcE).setMinter(address(lancaCanonicalBridge));
        MockUSDCe(usdcE).mintTo(user, AMOUNT);

        vm.deal(user, 1e18);

        vm.startPrank(deployer);
        lancaCanonicalBridge.setRateLimit(
            SRC_CHAIN_SELECTOR,
            MAX_RATE_AMOUNT,
            REFILL_SPEED,
            true
        );

        lancaCanonicalBridge.setRateLimit(
            SRC_CHAIN_SELECTOR,
            MAX_RATE_AMOUNT,
            REFILL_SPEED,
            false
        );
        vm.stopPrank();
    }

    function _approveBridge(uint256 amount) internal {
        vm.prank(user);
        MockUSDCe(usdcE).approve(address(lancaCanonicalBridge), amount);
    }

    function _getMessageFee() internal view returns (uint256) {
        return LancaCanonicalBridge(address(lancaCanonicalBridge)).getBridgeNativeFee(ZERO_AMOUNT);
    }

    function _encodeBridgeParams(
        address tokenSender,
        address tokenReceiver,
        uint256 tokenAmount,
        uint256 dstGasLimit,
        bytes memory dstCallData
    ) internal pure returns (bytes memory) {
        return abi.encode(tokenSender, tokenReceiver, tokenAmount, dstGasLimit, dstCallData);
    }

    function _buildMessageRequest(
        address tokenSender,
        address tokenReceiver,
        uint256 tokenAmount,
        uint256 dstGasLimit,
        bytes memory dstCallData
    ) internal view returns (IConceroRouter.MessageRequest memory) {
        bytes memory payload = _encodeBridgeParams(
            tokenSender,
            tokenReceiver,
            tokenAmount,
            dstGasLimit,
            dstCallData
        );
        return _buildMessageRequest(payload, 300_000, type(uint64).max, address(0));
    }

    function _buildMessageRequest(
        bytes memory payload,
        uint32 dstChainGasLimit,
        uint64 srcBlockConfirmations,
        address feeToken
    ) internal view returns (IConceroRouter.MessageRequest memory) {
        address[] memory validatorLibs = new address[](1);
        validatorLibs[0] = validatorLib;

        return
            IConceroRouter.MessageRequest({
                dstChainSelector: DST_CHAIN_SELECTOR,
                srcBlockConfirmations: srcBlockConfirmations,
                feeToken: feeToken,
                dstChainData: MessageCodec.encodeEvmDstChainData(
                    address(lancaCanonicalBridge),
                    dstChainGasLimit
                ),
                validatorLibs: validatorLibs,
                relayerLib: relayerLib,
                validatorConfigs: new bytes[](1),
                relayerConfig: new bytes(1),
                payload: payload
            });
    }
}
