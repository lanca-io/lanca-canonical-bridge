// SPDX-License-Identifier: MIT
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {ReentrancyGuard} from "@openzeppelin/contracts-v5/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts-v5/token/ERC20/utils/SafeERC20.sol";

import {MessageCodec} from "@concero/v2-contracts/contracts/common/libraries/MessageCodec.sol";
import {CommonErrors} from "@concero/v2-contracts/contracts/common/CommonErrors.sol";

import {BridgeCodec} from "../common/libraries/BridgeCodec.sol";
import {
    LancaCanonicalBridgeBase,
    ILancaCanonicalBridgeClient
} from "./LancaCanonicalBridgeBase.sol";

contract LancaCanonicalBridge is LancaCanonicalBridgeBase, ReentrancyGuard {
    using BridgeCodec for address;
    using BridgeCodec for bytes;
    using MessageCodec for bytes;

    uint24 internal immutable i_l1ChainSelector;
    address internal immutable i_lancaCanonicalBridgeL1;

    constructor(
        uint24 l1ChainSelector,
        address conceroRouter,
        address usdcAddress,
        address lancaCanonicalBridgeL1,
        address rateLimitAdmin
    ) LancaCanonicalBridgeBase(usdcAddress, rateLimitAdmin, conceroRouter) {
        i_l1ChainSelector = l1ChainSelector;
        i_lancaCanonicalBridgeL1 = lancaCanonicalBridgeL1;
    }

    /* ------- Main Functions ------- */

    function sendToken(
        uint256 tokenAmount,
        bytes calldata dstChainData,
        bytes calldata payload
    ) external payable nonReentrant returns (bytes32 messageId) {
        require(tokenAmount > 0, CommonErrors.InvalidAmount());

        _consumeRate(i_l1ChainSelector, tokenAmount, true);

        SafeERC20.safeTransferFrom(i_usdc, msg.sender, address(this), tokenAmount);
        i_usdc.burn(tokenAmount);

        messageId = _sendMessage(
            tokenAmount,
            i_l1ChainSelector,
            payload,
            dstChainData,
            i_lancaCanonicalBridgeL1.toBytes32()
        );

        emit TokenSent(messageId, i_l1ChainSelector, dstChainData, msg.sender, tokenAmount);
    }

    function _conceroReceive(bytes calldata messageReceipt) internal override nonReentrant {
        (address sender, ) = messageReceipt.evmSrcChainData();
        uint24 srcChainSelector = messageReceipt.srcChainSelector();

        require(
            sender == i_lancaCanonicalBridgeL1 && srcChainSelector == i_l1ChainSelector,
            InvalidBridgeSender()
        );

        bytes calldata messageData = messageReceipt.calldataPayload();
        bytes32 messageId = keccak256(messageReceipt);

        (
            bytes32 tokenSender,
            uint256 tokenAmount,
            bytes calldata dstChainData,
            bytes memory payload
        ) = messageData.decodeBridgeData();

        (address tokenReceiver, uint32 dstGasLimit) = dstChainData.decodeEvmDstChainData();

        _consumeRate(srcChainSelector, tokenAmount, false);

        bool shouldCallHook = _validateBridgeParams(dstGasLimit, tokenReceiver, payload);

        i_usdc.mint(tokenReceiver, tokenAmount);

        if (shouldCallHook) {
            ILancaCanonicalBridgeClient(tokenReceiver).lancaCanonicalBridgeReceive(
                messageId,
                srcChainSelector,
                tokenSender,
                tokenAmount,
                payload
            );
        }

        emit BridgeDelivered(messageId, tokenAmount);
    }

    /* ------- View Functions ------- */

    function getBridgeNativeFee(
        uint256 /* tokenAmount */,
        uint24 dstChainSelector,
        bytes calldata dstChainData,
        bytes calldata payload
    ) external view returns (uint256) {
        return
            _getBridgeNativeFee(
                dstChainSelector,
                dstChainData,
                payload,
                i_lancaCanonicalBridgeL1.toBytes32()
            );
    }
}
