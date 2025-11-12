// SPDX-License-Identifier: MIT
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {IERC165} from "@openzeppelin/contracts-v5/utils/introspection/IERC165.sol";

import {ConceroClient} from "@concero/v2-contracts/contracts/ConceroClient/ConceroClient.sol";
import {ConceroOwnable} from "@concero/v2-contracts/contracts/common/ConceroOwnable.sol";
import {IConceroRouter} from "@concero/v2-contracts/contracts/interfaces/IConceroRouter.sol";

// TODO: import from concero-v2-contracts
import {MessageCodec} from "contracts/common/libraries/MessageCodec.sol";

import {RateLimiter} from "./RateLimiter.sol";
import {IFiatTokenV1} from "../interfaces/IFiatTokenV1.sol";
import {ILancaCanonicalBridgeClient} from "../LancaCanonicalBridgeClient/LancaCanonicalBridgeClient.sol";

abstract contract LancaCanonicalBridgeBase is ConceroClient, RateLimiter, ConceroOwnable {
    uint256 internal constant BRIDGE_GAS_OVERHEAD = 150_000;

    IFiatTokenV1 internal immutable i_usdc;

    event TokenSent(
        bytes32 indexed messageId,
        address tokenSender,
        address tokenReceiver,
        uint24 dstChainSelector,
        uint256 tokenAmount
    );
    event BridgeDelivered(bytes32 indexed messageId, uint256 tokenAmountWithFee);

    error InvalidBridgeSender();
    error InvalidDstGasLimitOrCallData();
    error InvalidConceroMessage();

    constructor(
        address usdcAddress,
        address rateLimitAdmin,
        address conceroRouter
    ) RateLimiter(rateLimitAdmin) ConceroClient(conceroRouter) {
        i_usdc = IFiatTokenV1(usdcAddress);
    }

    function _sendMessage(
        address tokenReceiver,
        uint256 tokenAmount,
        uint24 dstChainSelector,
        uint256 dstGasLimit,
        bytes calldata dstCallData,
        address dstBridge,
        address relayerLib,
        bytes memory relayerConfig,
        address[] memory validatorLibs,
        bytes[] memory validatorConfigs
    ) internal returns (bytes32 messageId) {
        require(
            (dstGasLimit == 0 && dstCallData.length == 0) ||
                (dstGasLimit > 0 && dstCallData.length > 0),
            InvalidDstGasLimitOrCallData()
        );

        bytes memory messageData = abi.encode(
            msg.sender,
            tokenReceiver,
            tokenAmount,
            dstGasLimit,
            dstCallData
        );

        IConceroRouter.MessageRequest memory messageRequest = IConceroRouter.MessageRequest({
            dstChainSelector: dstChainSelector,
            srcBlockConfirmations: type(uint64).max,
            feeToken: address(0),
            dstChainData: MessageCodec.encodeEvmDstChainData(
                dstBridge,
                BRIDGE_GAS_OVERHEAD + dstGasLimit
            ),
            validatorLibs: validatorLibs,
            relayerLib: relayerLib,
            validatorConfigs: validatorConfigs,
            relayerConfig: relayerConfig,
            payload: messageData
        });

        messageId = IConceroRouter(i_conceroRouter).conceroSend{value: msg.value}(messageRequest);
    }

    function _isValidContractReceiver(address tokenReceiver) internal view returns (bool) {
        if (
            tokenReceiver.code.length == 0 ||
            !IERC165(tokenReceiver).supportsInterface(type(ILancaCanonicalBridgeClient).interfaceId)
        ) {
            return false;
        }

        return true;
    }

    function _getBridgeNativeFee(
        uint24 dstChainSelector,
        address dstPool,
        uint256 dstGasLimit,
        address relayerLib,
        bytes memory relayerConfig,
        address[] memory validatorLibs,
        bytes[] memory validatorConfigs
    ) internal view returns (uint256) {
        IConceroRouter.MessageRequest memory messageRequest = IConceroRouter.MessageRequest({
            dstChainSelector: dstChainSelector,
            srcBlockConfirmations: type(uint64).max,
            feeToken: address(0),
            dstChainData: MessageCodec.encodeEvmDstChainData(
                dstPool,
                BRIDGE_GAS_OVERHEAD + dstGasLimit
            ),
            validatorLibs: validatorLibs,
            relayerLib: relayerLib,
            validatorConfigs: validatorConfigs,
            relayerConfig: relayerConfig,
            payload: new bytes(0)
        });

        return IConceroRouter(i_conceroRouter).getMessageFee(messageRequest);
    }
}
