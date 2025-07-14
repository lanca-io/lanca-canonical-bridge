// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting

 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {ConceroTypes} from "@concero/messaging-contracts-v2/contracts/ConceroClient/ConceroTypes.sol";
import {IConceroRouter} from "@concero/messaging-contracts-v2/contracts/interfaces/IConceroRouter.sol";

contract MockConceroRouter is IConceroRouter {
    uint256 public constant MESSAGE_FEE = 100;

    address public tokenReceiver;
    uint256 public tokenAmount;
    uint8 public isContract;
    bytes public dstCallData;

    function conceroSend(
        uint24 /* dstChainSelector */,
        bool /* shouldFinaliseSrc */,
        address /* feeToken */,
        ConceroTypes.EvmDstChainData memory /* dstChainData */,
        bytes calldata message
    ) external payable returns (bytes32 messageId) {
        if (message.length > 64) {
            (tokenReceiver, tokenAmount) = abi.decode(message[:64], (address, uint256));
            isContract = uint8(message[64]);
            dstCallData = message[65:];
        } else {
            (tokenReceiver, tokenAmount) = abi.decode(message, (address, uint256));
            dstCallData = "";
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
