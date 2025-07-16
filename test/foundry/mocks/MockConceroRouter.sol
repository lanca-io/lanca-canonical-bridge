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

    address public tokenSender;
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
        // decode the message payload
        // payload: [bytes32,bytes32,bytes32,bytes1,bytes]
        // bytes32: address(tokenSender)   : 0 - 31
        // bytes32: address(tokenReceiver) : 32 - 63
        // bytes32: uint256(tokenAmount)   : 64 - 95
        // bytes1 : uint8(isContractFlag)  : 96
        // bytes  : bytes(dstCallData)     : 97 - ...
        if (message.length > 96) {
            (tokenSender, tokenReceiver, tokenAmount) = abi.decode(
                message[:96],
                (address, address, uint256)
            );
            isContract = uint8(message[96]);
            dstCallData = message[97:];
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
