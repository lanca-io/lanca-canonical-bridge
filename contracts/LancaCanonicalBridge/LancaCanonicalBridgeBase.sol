// SPDX-License-Identifier: MIT
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {ConceroClient} from "@concero/messaging-contracts-v2/contracts/ConceroClient/ConceroClient.sol";
import {ConceroOwnable} from "@concero/messaging-contracts-v2/contracts/common/ConceroOwnable.sol";
import {ConceroTypes} from "@concero/messaging-contracts-v2/contracts/ConceroClient/ConceroTypes.sol";
import {IConceroRouter} from "@concero/messaging-contracts-v2/contracts/interfaces/IConceroRouter.sol";

import {RateLimiter} from "./RateLimiter.sol";
import {IFiatTokenV1} from "../interfaces/IFiatTokenV1.sol";
import {LancaCanonicalBridgeClient, ILancaCanonicalBridgeClient} from "../LancaCanonicalBridgeClient/LancaCanonicalBridgeClient.sol";

abstract contract LancaCanonicalBridgeBase is ConceroClient, RateLimiter, ConceroOwnable {
    uint256 internal constant BRIDGE_GAS_OVERHEAD = 100_000;

    IFiatTokenV1 internal immutable i_usdc;

    enum MessageType {
        TRANSFER,
        TRANSFER_AND_CALL
    }

    event TokenSent(
        bytes32 indexed messageId,
        address indexed dstBridge,
        uint24 indexed dstChainSelector,
        address tokenSender,
        address tokenReceiver,
        uint256 tokenAmount,
        uint256 fee
    );

    event TokenReceived(
        bytes32 indexed messageId,
        address indexed srcBridge,
        uint24 indexed srcChainSelector,
        address tokenSender,
        address tokenReceiver,
        uint256 tokenAmount
    );

    error InvalidSenderBridge();
    error InvalidMessageType();

    constructor(
        address usdcAddress,
        address rateLimitAdmin
    ) ConceroOwnable() RateLimiter(rateLimitAdmin) {
        i_usdc = IFiatTokenV1(usdcAddress);
    }

    function _sendMessage(
        address tokenReceiver,
        uint256 tokenAmount,
        uint24 dstChainSelector,
        bool isContract,
        uint256 dstGasLimit,
        bytes calldata dstCallData,
        address dstBridge
    ) internal returns (bytes32 messageId) {
        ConceroTypes.EvmDstChainData memory dstChainData = ConceroTypes.EvmDstChainData({
            receiver: dstBridge,
            gasLimit: isContract ? BRIDGE_GAS_OVERHEAD + dstGasLimit : BRIDGE_GAS_OVERHEAD
        });

        uint256 fee = getMessageFee(dstChainSelector, address(0), dstChainData);
        require(msg.value >= fee, InsufficientFee(msg.value, fee));

        bytes memory message;
        if (isContract) {
            message = abi.encode(msg.sender, tokenReceiver, tokenAmount, dstCallData);
        } else {
            message = abi.encode(msg.sender, tokenReceiver, tokenAmount);
        }

        messageId = IConceroRouter(i_conceroRouter).conceroSend{value: msg.value}(
            dstChainSelector,
            false,
            address(0),
            dstChainData,
            abi.encode(
                isContract ? uint8(MessageType.TRANSFER_AND_CALL) : uint8(MessageType.TRANSFER),
                message
            )
        );
    }

    function _decodeMessage(
        bytes calldata message
    )
        internal
        pure
        returns (
            address tokenSender,
            address tokenReceiver,
            uint256 tokenAmount,
            uint8 messageType,
            bytes memory dstCallData
        )
    {
        bytes memory decodedMessage;
        (messageType, decodedMessage) = abi.decode(message, (uint8, bytes));

        if (messageType == uint8(MessageType.TRANSFER)) {
            (tokenSender, tokenReceiver, tokenAmount) = abi.decode(
                decodedMessage,
                (address, address, uint256)
            );
        } else if (messageType == uint8(MessageType.TRANSFER_AND_CALL)) {
            (tokenSender, tokenReceiver, tokenAmount, dstCallData) = abi.decode(
                decodedMessage,
                (address, address, uint256, bytes)
            );
        } else {
            revert InvalidMessageType();
        }
    }

    function _callTokenReceiver(
        address tokenSender,
        address tokenReceiver,
        uint256 tokenAmount,
        bytes memory dstCallData
    ) internal {
        bytes4 magicValue = LancaCanonicalBridgeClient(tokenReceiver).lancaCanonicalBridgeReceive(
            address(i_usdc),
            tokenSender,
            tokenAmount,
            dstCallData
        );

        require(
            magicValue == ILancaCanonicalBridgeClient.lancaCanonicalBridgeReceive.selector,
            ILancaCanonicalBridgeClient.CallFiled()
        );
    }

    function _getMessageFeeForContract(
        uint24 dstChainSelector,
        address dstBridge,
        address feeToken,
        uint256 dstGasLimit,
        bytes calldata /** dstCallData */
    ) internal view returns (uint256) {
        return
            getMessageFee(
                dstChainSelector,
                feeToken,
                ConceroTypes.EvmDstChainData({
                    receiver: dstBridge,
                    gasLimit: BRIDGE_GAS_OVERHEAD + dstGasLimit
                })
            );
    }

    /* ------- View Functions ------- */

    function getMessageFee(
        uint24 dstChainSelector,
        address feeToken,
        ConceroTypes.EvmDstChainData memory dstChainData
    ) public view returns (uint256) {
        return
            IConceroRouter(i_conceroRouter).getMessageFee(
                dstChainSelector,
                false,
                feeToken,
                dstChainData
            );
    }
}
