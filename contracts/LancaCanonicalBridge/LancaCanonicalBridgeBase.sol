// SPDX-License-Identifier: MIT
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {ConceroClient} from "@concero/messaging-contracts-v2/contracts/ConceroClient/ConceroClient.sol";
import {ConceroOwnable} from "@concero/messaging-contracts-v2/contracts/common/ConceroOwnable.sol";
import {ConceroTypes} from "@concero/messaging-contracts-v2/contracts/ConceroClient/ConceroTypes.sol";
import {IConceroRouter} from "@concero/messaging-contracts-v2/contracts/interfaces/IConceroRouter.sol";

import {RateLimiter} from "./RateLimiter.sol";
import {IFiatTokenV1} from "../interfaces/IFiatTokenV1.sol";
import {LancaCanonicalBridgeClient, ILancaCanonicalBridgeClient} from "../LancaCanonicalBridgeClient/LancaCanonicalBridgeClient.sol";

abstract contract LancaCanonicalBridgeBase is ConceroClient, RateLimiter, ConceroOwnable {
    uint256 internal constant BRIDGE_GAS_OVERHEAD = 100_000;

    IFiatTokenV1 internal immutable i_usdc;

    enum BridgeType {
        EOA_TRANSFER,
        CONTRACT_TRANSFER
    }

    event TokenSent(
        bytes32 indexed messageId,
        address indexed tokenSender,
        address indexed tokenReceiver,
        uint256 tokenAmount
    );

    event SentToDestinationBridge(
        bytes32 indexed messageId,
        uint24 indexed dstChainSelector,
        address indexed dstBridge
    );

    event BridgeDelivered(
        bytes32 indexed messageId,
        address indexed srcBridge,
        uint24 indexed srcChainSelector,
        address tokenSender,
        address tokenReceiver,
        uint256 tokenAmount
    );

    error InvalidBridgeSender();
    error InvalidBridgeType();

    constructor(
        address usdcAddress,
        address rateLimitAdmin
    ) ConceroOwnable() RateLimiter(rateLimitAdmin) {
        i_usdc = IFiatTokenV1(usdcAddress);
    }

    function _sendMessage(
        address tokenReceiver,
        uint256 tokenAmount,
        uint24 dstChainSelector,
        bool isTokenReceiverContract,
        uint256 dstGasLimit,
        bytes calldata dstCallData,
        address dstBridge
    ) internal returns (bytes32 messageId) {
        bytes memory bridgeData;
        if (isTokenReceiverContract) {
            bridgeData = abi.encode(msg.sender, tokenReceiver, tokenAmount, dstCallData);
        } else {
            bridgeData = abi.encode(msg.sender, tokenReceiver, tokenAmount);
        }

        messageId = IConceroRouter(i_conceroRouter).conceroSend{value: msg.value}(
            dstChainSelector,
            false,
            address(0),
            ConceroTypes.EvmDstChainData({
                receiver: dstBridge,
                gasLimit: isTokenReceiverContract
                    ? BRIDGE_GAS_OVERHEAD + dstGasLimit
                    : BRIDGE_GAS_OVERHEAD
            }),
            abi.encode(
                isTokenReceiverContract
                    ? uint8(BridgeType.CONTRACT_TRANSFER)
                    : uint8(BridgeType.EOA_TRANSFER),
                bridgeData
            )
        );
    }

    function _decodeMessage(
        bytes calldata message
    )
        internal
        pure
        returns (
            address tokenSender,
            address tokenReceiver,
            uint256 tokenAmount,
            uint8 bridgeType,
            bytes memory dstCallData
        )
    {
        bytes memory bridgeData;
        (bridgeType, bridgeData) = abi.decode(message, (uint8, bytes));

        if (bridgeType == uint8(BridgeType.EOA_TRANSFER)) {
            (tokenSender, tokenReceiver, tokenAmount) = abi.decode(
                bridgeData,
                (address, address, uint256)
            );
        } else if (bridgeType == uint8(BridgeType.CONTRACT_TRANSFER)) {
            (tokenSender, tokenReceiver, tokenAmount, dstCallData) = abi.decode(
                bridgeData,
                (address, address, uint256, bytes)
            );
        } else {
            revert InvalidBridgeType();
        }
    }

    function _callTokenReceiver(
        address tokenSender,
        address tokenReceiver,
        uint256 tokenAmount,
        bytes memory dstCallData
    ) internal {
        bytes4 expectedSelector = LancaCanonicalBridgeClient(tokenReceiver)
            .lancaCanonicalBridgeReceive(address(i_usdc), tokenSender, tokenAmount, dstCallData);

        require(
            expectedSelector == ILancaCanonicalBridgeClient.lancaCanonicalBridgeReceive.selector,
            ILancaCanonicalBridgeClient.CallFiled()
        );
    }

    function _getMessageFeeForContract(
        uint24 dstChainSelector,
        address dstBridge,
        address feeToken,
        uint256 dstGasLimit,
        bytes calldata /** dstCallData */
    ) internal view returns (uint256) {
        return
            getMessageFee(
                dstChainSelector,
                feeToken,
                ConceroTypes.EvmDstChainData({
                    receiver: dstBridge,
                    gasLimit: BRIDGE_GAS_OVERHEAD + dstGasLimit
                })
            );
    }

    /* ------- View Functions ------- */

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
