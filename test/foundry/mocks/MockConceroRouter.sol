// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting

 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {ConceroTypes} from "@concero/messaging-contracts-v2/contracts/ConceroClient/ConceroTypes.sol";
import {IConceroRouter} from "@concero/messaging-contracts-v2/contracts/interfaces/IConceroRouter.sol";

import {LCBridgeCallData} from "contracts/LancaCanonicalBridge/LancaCanonicalBridgeBase.sol";

contract MockConceroRouter is IConceroRouter {
    uint256 public constant MESSAGE_FEE = 100;

    address public tokenSender;
    uint256 public amount;
    LCBridgeCallData public lcbCallData;

    function conceroSend(
        uint24 /* dstChainSelector */,
        bool /* shouldFinaliseSrc */,
        address /* feeToken */,
        ConceroTypes.EvmDstChainData memory /* dstChainData */,
        bytes calldata message
    ) external payable returns (bytes32 messageId) {
        if (message.length > 64) {
            (tokenSender, amount, lcbCallData) = abi.decode(
                message,
                (address, uint256, LCBridgeCallData)
            );
        } else {
            (tokenSender, amount) = abi.decode(message, (address, uint256));
        }

        return bytes32(uint256(1));
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
