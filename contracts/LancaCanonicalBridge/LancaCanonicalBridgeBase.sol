// SPDX-License-Identifier: MIT
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {IConceroRouter} from "@concero/messaging-contracts-v2/contracts/interfaces/IConceroRouter.sol";
import {CommonErrors} from "@concero/messaging-contracts-v2/contracts/common/CommonErrors.sol";
import {ConceroClient} from "@concero/messaging-contracts-v2/contracts/ConceroClient/ConceroClient.sol";
import {ConceroOwnable} from "@concero/messaging-contracts-v2/contracts/common/ConceroOwnable.sol";
import {ConceroTypes} from "@concero/messaging-contracts-v2/contracts/ConceroClient/ConceroTypes.sol";

import {RateLimiter} from "./RateLimiter.sol";
import {IFiatTokenV1} from "../interfaces/IFiatTokenV1.sol";

struct LCBridgeCallData {
    address tokenReceiver;
    bytes receiverData;
}

abstract contract LancaCanonicalBridgeBase is ConceroClient, RateLimiter, ConceroOwnable {
    IFiatTokenV1 internal immutable i_usdc;

    event TokenSent(
        bytes32 indexed messageId,
        address indexed dstBridgeAddress,
        uint24 indexed dstChainSelector,
        address tokenSender,
        uint256 amount,
        uint256 fee
    );

    event TokenReceived(
        bytes32 indexed messageId,
        uint24 indexed srcChainSelector,
        address sender,
        address tokenSender,
        uint256 amount
    );

    error InvalidSenderBridge();

    constructor(address usdcAddress, address rateAdmin) ConceroOwnable() RateLimiter(rateAdmin) {
        i_usdc = IFiatTokenV1(usdcAddress);
    }

    function getMessageFee(
        uint24 dstChainSelector,
        address feeToken,
        ConceroTypes.EvmDstChainData memory dstChainData
    ) public view returns (uint256) {
        return
            IConceroRouter(i_conceroRouter).getMessageFee(
                dstChainSelector,
                false,
                feeToken,
                dstChainData
            );
    }
}
