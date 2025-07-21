// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting

 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {ConceroTypes} from "@concero/messaging-contracts-v2/contracts/ConceroClient/ConceroTypes.sol";
import {IConceroRouter} from "@concero/messaging-contracts-v2/contracts/interfaces/IConceroRouter.sol";

import {LancaCanonicalBridgeBase} from "contracts/LancaCanonicalBridge/LancaCanonicalBridgeBase.sol";

contract MockConceroRouter is IConceroRouter {
    uint256 public constant MESSAGE_FEE = 100;

    address public s_tokenSender;
    address public s_tokenReceiver;
    uint256 public s_tokenAmount;
    uint8 public s_isContract;
    bytes public s_dstCallData;

    function conceroSend(
        uint24 /* dstChainSelector */,
        bool /* shouldFinaliseSrc */,
        address /* feeToken */,
        ConceroTypes.EvmDstChainData memory /* dstChainData */,
        bytes calldata message
    ) external payable returns (bytes32 messageId) {
        (
            s_tokenSender,
            s_tokenReceiver,
            s_tokenAmount,
            s_isContract,
            s_dstCallData
        ) = _decodeMessage(message);
        return bytes32(uint256(1));
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
            uint8 bridgeType,
            bytes memory dstCallData
        )
    {
        bytes memory decodedMessage;
        (bridgeType, decodedMessage) = abi.decode(message, (uint8, bytes));

        if (bridgeType == uint8(LancaCanonicalBridgeBase.BridgeType.EOA_TRANSFER)) {
            (tokenSender, tokenReceiver, tokenAmount) = abi.decode(
                decodedMessage,
                (address, address, uint256)
            );
        } else if (bridgeType == uint8(LancaCanonicalBridgeBase.BridgeType.CONTRACT_TRANSFER)) {
            (tokenSender, tokenReceiver, tokenAmount, dstCallData) = abi.decode(
                decodedMessage,
                (address, address, uint256, bytes)
            );
        } else {
            revert LancaCanonicalBridgeBase.InvalidBridgeType();
        }
    }

    function getMessageFee(
        uint24 /* dstChainSelector */,
        bool /* shouldFinaliseSrc */,
        address /* feeToken */,
        ConceroTypes.EvmDstChainData memory /* dstChainData */
    ) external pure returns (uint256) {
        return MESSAGE_FEE;
    }
}
