// SPDX-License-Identifier: MIT
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {CommonErrors} from "@concero/v2-contracts/contracts/common/CommonErrors.sol";

import {LancaCanonicalBridgeBase, ILancaCanonicalBridgeClient, ConceroClient} from "./LancaCanonicalBridgeBase.sol";
import {ReentrancyGuard} from "../common/ReentrancyGuard.sol";

contract LancaCanonicalBridge is LancaCanonicalBridgeBase, ReentrancyGuard {
    uint24 internal immutable i_dstChainSelector;
    address internal immutable i_lancaCanonicalBridgeL1;

    constructor(
        uint24 dstChainSelector,
        address conceroRouter,
        address usdcAddress,
        address lancaCanonicalBridgeL1,
        address rateLimitAdmin
    ) LancaCanonicalBridgeBase(usdcAddress, rateLimitAdmin) ConceroClient(conceroRouter) {
        i_dstChainSelector = dstChainSelector;
        i_lancaCanonicalBridgeL1 = lancaCanonicalBridgeL1;
    }

    /* ------- Main Functions ------- */

    function sendToken(
        address tokenReceiver,
        uint256 tokenAmount,
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
            dstGasLimit,
            dstCallData,
            i_lancaCanonicalBridgeL1
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
        require(messageSender == i_lancaCanonicalBridgeL1, InvalidBridgeSender());

        (
            address tokenSender,
            address tokenReceiver,
            uint256 tokenAmount,
            uint256 dstGasLimit,
            bytes memory dstCallData
        ) = _decodeMessage(message);

        _consumeRate(srcChainSelector, tokenAmount, false);

        if (dstGasLimit == 0 && dstCallData.length == 0) {
            _mintToken(tokenReceiver, tokenAmount);
        } else if (_isValidContractReceiver(tokenReceiver)) {
            _mintToken(tokenReceiver, tokenAmount);

            ILancaCanonicalBridgeClient(tokenReceiver).lancaCanonicalBridgeReceive{
                gas: dstGasLimit
            }(address(i_usdc), tokenSender, tokenAmount, dstCallData);
        }

        emit BridgeDelivered(
            messageId,
            i_lancaCanonicalBridgeL1,
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
                i_lancaCanonicalBridgeL1,
                feeToken,
                dstGasLimit,
                dstCallData
            );
    }
}
