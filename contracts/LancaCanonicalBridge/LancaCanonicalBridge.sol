// SPDX-License-Identifier: MIT
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

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
        bool isTokenReceiverContract,
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
            isTokenReceiverContract,
            dstGasLimit,
            dstCallData,
            i_lancaBridgeL1
        );

        emit TokenSent(messageId, msg.sender, tokenReceiver, tokenAmount);
    }

    function _conceroReceive(
        bytes32 messageId,
        uint24 srcChainSelector,
        bytes calldata sender,
        bytes calldata message
    ) internal override nonReentrant {
        address messageSender = abi.decode(sender, (address));
        require(messageSender == i_lancaBridgeL1, InvalidBridgeSender());

        (
            address tokenSender,
            address tokenReceiver,
            uint256 tokenAmount,
            uint8 bridgeType,
            bytes memory dstCallData
        ) = _decodeMessage(message);

        _consumeRate(srcChainSelector, tokenAmount, false);

        if (bridgeType == uint8(BridgeType.CONTRACT_TRANSFER)) {
            _mintToken(tokenReceiver, tokenAmount);
            _callTokenReceiver(tokenSender, tokenReceiver, tokenAmount, dstCallData);
        } else {
            _mintToken(tokenReceiver, tokenAmount);
        }

        emit BridgeDelivered(
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
        SafeERC20.safeTransferFrom(i_usdc, tokenSender, address(this), tokenAmount);
        i_usdc.burn(tokenAmount);
    }

    function _mintToken(address to, uint256 amount) private {
        i_usdc.mint(to, amount);
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
