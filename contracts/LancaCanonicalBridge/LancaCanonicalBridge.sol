// SPDX-License-Identifier: MIT
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {Utils} from "@concero/messaging-contracts-v2/contracts/common/libraries/Utils.sol";

import {ILancaCanonicalBridgeClient} from "../interfaces/ILancaCanonicalBridgeClient.sol";
import {LancaCanonicalBridgeBase, ConceroClient, CommonErrors, ConceroTypes, IConceroRouter} from "./LancaCanonicalBridgeBase.sol";
import {ReentrancyGuard} from "../common/ReentrancyGuard.sol";

contract LancaCanonicalBridge is LancaCanonicalBridgeBase, ReentrancyGuard {
    uint16 private constant MAX_RET_BYTES = 256;

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
        require(amount > 0, CommonErrors.InvalidAmount());

        uint256 fee = getMessageFee(i_dstChainSelector, address(0), dstChainData);
        require(msg.value >= fee, InsufficientFee(msg.value, fee));

        bool success = i_usdc.transferFrom(msg.sender, address(this), amount);
        require(success, CommonErrors.TransferFailed());

        i_usdc.burn(amount);

        bytes memory message = abi.encode(msg.sender, amount);
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
        address tokenSender;
        uint256 amount;
        address target;
        bytes memory data;

        if (message.length > 64) {
            (tokenSender, amount, target, data) = abi.decode(
                message,
                (address, uint256, address, bytes)
            );
        } else {
            (tokenSender, amount) = abi.decode(message, (address, uint256));
        }

        if (target != address(0) && Utils.isContract(target)) {
            _mintToken(target, amount);
            _externalCall(tokenSender, amount, target, data);
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

    function _externalCall(
        address tokenSender,
        uint256 amount,
        address target,
        bytes memory data
    ) internal {
        bytes memory callData = abi.encodeWithSelector(
            ILancaCanonicalBridgeClient.lancaCanonicalBridgeReceive.selector,
            address(i_usdc),
            tokenSender,
            amount,
            data
        );

        uint256 callGas = (gasleft() * 63) / 64;

        (bool callResult, bytes memory returnData) = Utils.safeCall(
            target,
            callGas,
            0,
            MAX_RET_BYTES,
            callData
        );

        if (callResult && returnData.length >= 32) {
            bytes4 returnSelector = abi.decode(returnData, (bytes4));
            require(
                returnSelector == ILancaCanonicalBridgeClient.lancaCanonicalBridgeReceive.selector,
                ILancaCanonicalBridgeClient.CallFiled()
            );
        }
    }
}
