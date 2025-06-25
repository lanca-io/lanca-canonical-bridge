// SPDX-License-Identifier: MIT
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {LancaCanonicalBridgeBase, ConceroClient, CommonErrors, ConceroTypes, IConceroRouter} from "./LancaCanonicalBridgeBase.sol";

contract LancaCanonicalBridge is LancaCanonicalBridgeBase {
    uint24 internal immutable i_dstChainSelector;
    address internal immutable i_lane;

    constructor(
        uint24 dstChainSelector,
        address conceroRouter,
        address usdcAddress,
        address lane
    ) LancaCanonicalBridgeBase(usdcAddress) ConceroClient(conceroRouter) {
        i_dstChainSelector = dstChainSelector;
        i_lane = lane;
    }

    function sendToken(
        uint256 amount,
        uint24 dstChainSelector,
        bool shouldFinaliseSrc,
        address /* feeToken */,
        ConceroTypes.EvmDstChainData memory dstChainData
    ) external payable returns (bytes32 messageId) {
        require(
            dstChainSelector == i_dstChainSelector && dstChainData.receiver == i_lane,
            InvalidLane()
        );

        bytes memory message = abi.encode(msg.sender, amount);

        uint256 fee = getMessageFee(
            dstChainSelector,
            shouldFinaliseSrc,
            address(0),
            dstChainData
        );

        require(msg.value >= fee, InsufficientFee(msg.value, fee));

        messageId = IConceroRouter(i_conceroRouter).conceroSend{value: msg.value}(
            dstChainSelector,
            shouldFinaliseSrc,
            address(0),
            dstChainData,
            message
        );

        bool success = i_usdc.transferFrom(msg.sender, address(this), amount);
        require(success, CommonErrors.TransferFailed());

        i_usdc.burn(amount);

        emit TokenSent(messageId, i_lane, dstChainSelector, msg.sender, amount, fee);
    }

    function _conceroReceive(
        bytes32 messageId,
        uint24 srcChainSelector,
        bytes calldata sender,
        bytes calldata message
    ) internal override {
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
