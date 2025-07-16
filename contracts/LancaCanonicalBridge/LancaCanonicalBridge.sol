// SPDX-License-Identifier: MIT
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {CommonErrors} from "@concero/messaging-contracts-v2/contracts/common/CommonErrors.sol";

import {LancaCanonicalBridgeBase, ConceroClient, ConceroTypes, IConceroRouter} from "./LancaCanonicalBridgeBase.sol";
import {ILancaCanonicalBridgeClient} from "../interfaces/ILancaCanonicalBridgeClient.sol";
import {LancaCanonicalBridgeClient} from "../LancaCanonicalBridgeClient/LancaCanonicalBridgeClient.sol";
import {ReentrancyGuard} from "../common/ReentrancyGuard.sol";

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

    function sendToken(
        address tokenReceiver,
        uint256 tokenAmount
    ) external payable nonReentrant returns (bytes32 messageId) {
        require(tokenAmount > 0, CommonErrors.InvalidAmount());

        _consumeRate(i_dstChainSelector, tokenAmount, true);

        // Process transfer and send message
        messageId = _processTransfer(tokenReceiver, tokenAmount);

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

    function _processTransfer(
        address tokenReceiver,
        uint256 tokenAmount
    ) internal returns (bytes32 messageId) {
        ConceroTypes.EvmDstChainData memory dstChainData = ConceroTypes.EvmDstChainData({
            receiver: i_lancaBridgeL1,
            gasLimit: BRIDGE_GAS_OVERHEAD
        });

        // check fee
        uint256 fee = getMessageFee(i_dstChainSelector, address(0), dstChainData);
        require(msg.value >= fee, InsufficientFee(msg.value, fee));

        // transfer tokens and burn
        bool success = i_usdc.transferFrom(msg.sender, address(this), tokenAmount);
        require(success, CommonErrors.TransferFailed());

        i_usdc.burn(tokenAmount);

        // send message
        bytes memory message = abi.encode(msg.sender, tokenReceiver, tokenAmount);
        messageId = IConceroRouter(i_conceroRouter).conceroSend{value: msg.value}(
            i_dstChainSelector,
            false,
            address(0),
            dstChainData,
            message
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

        // decode the message payload
        // payload: [bytes32,bytes32,bytes32,bytes1,bytes]
        // bytes32: address(tokenSender)   : 0 - 31
        // bytes32: address(tokenReceiver) : 32 - 63
        // bytes32: uint256(tokenAmount)   : 64 - 95
        // bytes1 : uint8(isContractFlag)  : 96
        // bytes  : bytes(dstCallData)     : 97 - ...
        (address tokenSender, address tokenReceiver, uint256 tokenAmount) = abi.decode(
            message[:96],
            (address, address, uint256)
        );
        bool isContractFlag = uint8(message[96]) > 0;

        _consumeRate(srcChainSelector, tokenAmount, false);

        if (isContractFlag) {
            _mintToken(tokenReceiver, tokenAmount);

            bytes memory dstCallData = message[97:];

            bytes4 magicValue = LancaCanonicalBridgeClient(tokenReceiver)
                .lancaCanonicalBridgeReceive(
                    address(i_usdc),
                    tokenSender,
                    tokenAmount,
                    dstCallData
                );

            require(
                magicValue == ILancaCanonicalBridgeClient.lancaCanonicalBridgeReceive.selector,
                ILancaCanonicalBridgeClient.CallFiled()
            );
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

    function _mintToken(address to, uint256 amount) internal {
        bool success = i_usdc.mint(to, amount);
        require(success, CommonErrors.TransferFailed());
    }

    function setRateLimit(
        uint128 maxAmount,
        uint128 refillSpeed,
        bool isOutbound
    ) external onlyRateLimitAdmin {
        _setRateLimit(i_dstChainSelector, maxAmount, refillSpeed, isOutbound);
    }
}
