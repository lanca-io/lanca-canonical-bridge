// SPDX-License-Identifier: MIT
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {LancaCanonicalBridgeBase, ConceroClient, CommonErrors, ConceroTypes, IConceroRouter} from "./LancaCanonicalBridgeBase.sol";
import {ReentrancyGuard} from "../common/ReentrancyGuard.sol";

contract LancaCanonicalBridge is LancaCanonicalBridgeBase, ReentrancyGuard {
    uint24 internal immutable i_dstChainSelector;
    address internal immutable i_lancaBridgeL1;

    constructor(
        uint24 dstChainSelector,
        address conceroRouter,
        address usdcAddress,
        address lancaBridgeL1
    ) LancaCanonicalBridgeBase(usdcAddress) ConceroClient(conceroRouter) {
        i_dstChainSelector = dstChainSelector;
        i_lancaBridgeL1 = lancaBridgeL1;
    }

    function sendToken(
        uint256 amount,
        address /* feeToken */,
        ConceroTypes.EvmDstChainData memory dstChainData
    ) external payable nonReentrant returns (bytes32 messageId) {
        bytes memory message = abi.encode(msg.sender, amount);

        uint256 fee = getMessageFee(i_dstChainSelector, address(0), dstChainData);
        require(msg.value >= fee, InsufficientFee(msg.value, fee));

        bool success = i_usdc.transferFrom(msg.sender, address(this), amount);
        require(success, CommonErrors.TransferFailed());

        i_usdc.burn(amount);

        messageId = IConceroRouter(i_conceroRouter).conceroSend{value: msg.value}(
            i_dstChainSelector,
            false,
            address(0),
            dstChainData,
            message
        );

        emit TokenSent(messageId, i_lancaBridgeL1, i_dstChainSelector, msg.sender, amount, fee);
    }

    function _conceroReceive(
        bytes32 messageId,
        uint24 srcChainSelector,
        bytes calldata sender,
        bytes calldata message
    ) internal override nonReentrant {
        (address tokenSender, uint256 amount) = abi.decode(message, (address, uint256));

        bool success = i_usdc.mint(tokenSender, amount);
        require(success, CommonErrors.TransferFailed());

        emit TokenReceived(
            messageId,
            srcChainSelector,
            address(bytes20(sender)),
            tokenSender,
            amount
        );
    }
}
