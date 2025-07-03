// SPDX-License-Identifier: MIT
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {Utils} from "@concero/messaging-contracts-v2/contracts/common/libraries/Utils.sol";

import {RateLimiter} from "./RateLimiter.sol";
import {LancaCanonicalBridgeBase, ConceroClient, CommonErrors, ConceroTypes, IConceroRouter, LCBridgeCallData} from "./LancaCanonicalBridgeBase.sol";
import {LancaCanonicalBridgeClient} from "../LancaCanonicalBridgeClient/LancaCanonicalBridgeClient.sol";
import {ILancaCanonicalBridgeClient} from "../interfaces/ILancaCanonicalBridgeClient.sol";
import {ReentrancyGuard} from "../common/ReentrancyGuard.sol";

contract LancaCanonicalBridge is LancaCanonicalBridgeBase, RateLimiter, ReentrancyGuard {
    uint16 private constant MAX_RET_BYTES = 256;

    uint24 internal immutable i_dstChainSelector;
    address internal immutable i_lancaBridgeL1;

    constructor(
        uint24 dstChainSelector,
        address conceroRouter,
        address usdcAddress,
        address lancaBridgeL1,
        address rateLimitAdmin
    )
        LancaCanonicalBridgeBase(usdcAddress)
        ConceroClient(conceroRouter)
        RateLimiter(rateLimitAdmin)
    {
        i_dstChainSelector = dstChainSelector;
        i_lancaBridgeL1 = lancaBridgeL1;
    }

    function sendToken(
        uint256 amount,
        address /* feeToken */,
        ConceroTypes.EvmDstChainData memory dstChainData
    ) external payable nonReentrant returns (bytes32 messageId) {
        require(amount > 0, CommonErrors.InvalidAmount());

        // Check outbound rate limit
        _checkOutboundRateLimit(i_dstChainSelector, amount);

        // Process transfer and send message
        messageId = _processTransfer(amount, dstChainData);

        emit TokenSent(
            messageId,
            i_lancaBridgeL1,
            i_dstChainSelector,
            msg.sender,
            amount,
            msg.value
        );
    }

    function _processTransfer(
        uint256 amount,
        ConceroTypes.EvmDstChainData memory dstChainData
    ) internal returns (bytes32 messageId) {
        // check fee
        uint256 fee = getMessageFee(i_dstChainSelector, address(0), dstChainData);
        require(msg.value >= fee, InsufficientFee(msg.value, fee));

        // transfer tokens and burn
        bool success = i_usdc.transferFrom(msg.sender, address(this), amount);
        require(success, CommonErrors.TransferFailed());

        i_usdc.burn(amount);

        // send message
        bytes memory message = abi.encode(msg.sender, amount);
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
        address tokenSender;
        uint256 amount;
        LCBridgeCallData memory lcbCallData;

        // decode the message
        if (message.length > 64) {
            (tokenSender, amount, lcbCallData) = abi.decode(
                message,
                (address, uint256, LCBridgeCallData)
            );
        } else {
            (tokenSender, amount) = abi.decode(message, (address, uint256));
        }

        // Check inbound rate limit
        _checkInboundRateLimit(srcChainSelector, amount);

        // check if the receiver is a valid LCB receiver
        bool isValidLCBReceiver;
        if (lcbCallData.tokenReceiver != address(0)) {
            isValidLCBReceiver =
                Utils.isContract(lcbCallData.tokenReceiver) &&
                LancaCanonicalBridgeClient(lcbCallData.tokenReceiver).supportsInterface(
                    type(ILancaCanonicalBridgeClient).interfaceId
                );
        }

        // if the receiver is a valid LancaCanonicalBridge receiver,
        // mint the token and call receive function
        if (isValidLCBReceiver) {
            _mintToken(lcbCallData.tokenReceiver, amount);

            bytes4 selector = ILancaCanonicalBridgeClient(lcbCallData.tokenReceiver)
                .lancaCanonicalBridgeReceive(
                    address(i_usdc),
                    tokenSender,
                    amount,
                    lcbCallData.receiverData
                );

            require(
                selector == ILancaCanonicalBridgeClient.lancaCanonicalBridgeReceive.selector,
                ILancaCanonicalBridgeClient.CallFiled()
            );
        } else {
            _mintToken(tokenSender, amount);
        }

        emit TokenReceived(
            messageId,
            srcChainSelector,
            address(bytes20(sender)),
            tokenSender,
            amount
        );
    }

    function _mintToken(address to, uint256 amount) internal {
        bool success = i_usdc.mint(to, amount);
        require(success, CommonErrors.TransferFailed());
    }

    function setInboundRateLimit(
        uint32 period,
        uint128 maxAmountPerPeriod
    ) external onlyRateLimitAdmin {
        setInboundRateLimit(i_dstChainSelector, period, maxAmountPerPeriod);
    }

    function setOutboundRateLimit(
        uint32 period,
        uint128 maxAmountPerPeriod
    ) external onlyRateLimitAdmin {
        setOutboundRateLimit(i_dstChainSelector, period, maxAmountPerPeriod);
    }

    function getOutboundRateLimitInfo()
        external
        view
        returns (
            uint128 usedAmount,
            uint32 period,
            uint128 maxAmountPerPeriod,
            uint32 lastReset,
            uint256 availableAmount
        )
    {
        return getOutboundRateLimitInfo(i_dstChainSelector);
    }

    function getInboundRateLimitInfo()
        external
        view
        returns (
            uint128 usedAmount,
            uint32 period,
            uint128 maxAmountPerPeriod,
            uint32 lastReset,
            uint256 availableAmount
        )
    {
        return getInboundRateLimitInfo(i_dstChainSelector);
    }
}
