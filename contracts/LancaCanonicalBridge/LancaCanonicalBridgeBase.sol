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

import {IFiatTokenV1} from "../interfaces/IFiatTokenV1.sol";

abstract contract LancaCanonicalBridgeBase is ConceroClient, ConceroOwnable {
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

    constructor(address usdcAddress) ConceroOwnable() {
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
