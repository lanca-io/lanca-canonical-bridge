// SPDX-License-Identifier: MIT
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {CommonErrors} from "@concero/messaging-contracts-v2/contracts/common/CommonErrors.sol";

import {LancaCanonicalBridgeBase, ConceroClient, ConceroTypes, IConceroRouter} from "./LancaCanonicalBridgeBase.sol";
import {ReentrancyGuard} from "../common/ReentrancyGuard.sol";
import {LancaCanonicalBridgeClient} from "../LancaCanonicalBridgeClient/LancaCanonicalBridgeClient.sol";
import {ILancaCanonicalBridgeClient} from "../interfaces/ILancaCanonicalBridgeClient.sol";

contract LancaCanonicalBridge is LancaCanonicalBridgeBase, ReentrancyGuard {
    uint24 internal immutable i_dstChainSelector;
    address internal immutable i_lancaBridgeL1;

    constructor(
        uint24 dstChainSelector,
        address conceroRouter,
        address usdcAddress,
        address lancaBridgeL1,
        address rateLimitAdmin
    ) LancaCanonicalBridgeBase(usdcAddress, rateLimitAdmin) ConceroClient(conceroRouter) {
        i_dstChainSelector = dstChainSelector;
        i_lancaBridgeL1 = lancaBridgeL1;
    }

    /* ------- Main Functions ------- */

    function sendToken(
        address tokenReceiver,
        uint256 tokenAmount,
        bool isContract,
        uint256 dstGasLimit,
        bytes calldata dstCallData
    ) external payable nonReentrant returns (bytes32 messageId) {
        require(tokenAmount > 0, CommonErrors.InvalidAmount());

        _consumeRate(i_dstChainSelector, tokenAmount, true);
        _processTransferAndBurn(msg.sender, tokenAmount);

        messageId = _sendMessage(
            tokenReceiver,
            tokenAmount,
            i_dstChainSelector,
            isContract,
            dstGasLimit,
            dstCallData,
            i_lancaBridgeL1
        );

        emit TokenSent(
            messageId,
            i_lancaBridgeL1,
            i_dstChainSelector,
            msg.sender,
            tokenReceiver,
            tokenAmount,
            msg.value
        );
    }

    function _conceroReceive(
        bytes32 messageId,
        uint24 srcChainSelector,
        bytes calldata sender,
        bytes calldata message
    ) internal override nonReentrant {
        address messageSender = abi.decode(sender, (address));
        require(messageSender == i_lancaBridgeL1, InvalidSenderBridge());

        (
            address tokenSender,
            address tokenReceiver,
            uint256 tokenAmount,
            uint8 messageType,
            bytes memory dstCallData
        ) = _decodeMessage(message);

        _consumeRate(srcChainSelector, tokenAmount, false);

        if (messageType == uint8(MessageType.TRANSFER_AND_CALL)) {
            _mintToken(tokenReceiver, tokenAmount);
            _callTokenReceiver(tokenSender, tokenReceiver, tokenAmount, dstCallData);
        } else {
            _mintToken(tokenReceiver, tokenAmount);
        }

        emit TokenReceived(
            messageId,
            i_lancaBridgeL1,
            srcChainSelector,
            tokenSender,
            tokenReceiver,
            tokenAmount
        );
    }

    /* ------- Private Functions ------- */

    function _processTransferAndBurn(address tokenSender, uint256 tokenAmount) private {
        bool success = i_usdc.transferFrom(tokenSender, address(this), tokenAmount);
        require(success, CommonErrors.TransferFailed());

        i_usdc.burn(tokenAmount);
    }

    function _mintToken(address to, uint256 amount) private {
        bool success = i_usdc.mint(to, amount);
        require(success, CommonErrors.TransferFailed());
    }

    /* ------- Admin Functions ------- */

    function setRateLimit(
        uint128 maxAmount,
        uint128 refillSpeed,
        bool isOutbound
    ) external onlyRateLimitAdmin {
        _setRateLimit(i_dstChainSelector, maxAmount, refillSpeed, isOutbound);
    }

    /* ------- View Functions ------- */

    function getMessageFeeForContract(
        address feeToken,
        uint256 dstGasLimit,
        bytes calldata dstCallData
    ) public view returns (uint256) {
        return
            _getMessageFeeForContract(
                i_dstChainSelector,
                i_lancaBridgeL1,
                feeToken,
                dstGasLimit,
                dstCallData
            );
    }
}
