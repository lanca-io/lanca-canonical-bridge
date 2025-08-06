// SPDX-License-Identifier: MIT
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {ConceroClient} from "@concero/v2-contracts/contracts/ConceroClient/ConceroClient.sol";
import {ConceroOwnable} from "@concero/v2-contracts/contracts/common/ConceroOwnable.sol";
import {ConceroTypes} from "@concero/v2-contracts/contracts/ConceroClient/ConceroTypes.sol";
import {IConceroRouter} from "@concero/v2-contracts/contracts/interfaces/IConceroRouter.sol";

import {RateLimiter} from "./RateLimiter.sol";
import {IFiatTokenV1} from "../interfaces/IFiatTokenV1.sol";
import {ILancaCanonicalBridgeClient} from "../LancaCanonicalBridgeClient/LancaCanonicalBridgeClient.sol";

abstract contract LancaCanonicalBridgeBase is ConceroClient, RateLimiter, ConceroOwnable {
    uint256 internal constant BRIDGE_GAS_OVERHEAD = 100_000;

    IFiatTokenV1 internal immutable i_usdc;

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
    error InvalidDstGasLimitOrCallData();
    error InvalidMessage();

    constructor(
        address usdcAddress,
        address rateLimitAdmin
    ) RateLimiter(rateLimitAdmin) {
        i_usdc = IFiatTokenV1(usdcAddress);
    }

    function _sendMessage(
        address tokenReceiver,
        uint256 tokenAmount,
        uint24 dstChainSelector,
        uint256 dstGasLimit,
        bytes calldata dstCallData,
        address dstBridge
    ) internal returns (bytes32 messageId) {
        require(
            (dstGasLimit == 0 && dstCallData.length == 0) ||
                (dstGasLimit > 0 && dstCallData.length > 0),
            InvalidDstGasLimitOrCallData()
        );

        bytes memory messageData = abi.encode(
            msg.sender,
            tokenReceiver,
            tokenAmount,
            dstGasLimit,
            dstCallData
        );

        messageId = IConceroRouter(i_conceroRouter).conceroSend{value: msg.value}(
            dstChainSelector,
            false,
            address(0),
            ConceroTypes.EvmDstChainData({
                receiver: dstBridge,
                gasLimit: BRIDGE_GAS_OVERHEAD + dstGasLimit
            }),
            messageData
        );
    }

    function _decodeMessage(
        bytes memory messageData
    )
        internal
        pure
        returns (
            address tokenSender,
            address tokenReceiver,
            uint256 tokenAmount,
            uint256 dstGasLimit,
            bytes memory dstCallData
        )
    {
        (tokenSender, tokenReceiver, tokenAmount, dstGasLimit, dstCallData) = abi.decode(
            messageData,
            (address, address, uint256, uint256, bytes)
        );
    }

    function _isValidContractReceiver(address tokenReceiver) internal view returns (bool) {
        if (
            tokenReceiver.code.length == 0 ||
            !IERC165(tokenReceiver).supportsInterface(type(ILancaCanonicalBridgeClient).interfaceId)
        ) {
            return false;
        }

        return true;
    }

    /* ------- View Functions ------- */

    function getBridgeNativeFee(
        uint24 dstChainSelector,
        address dstPool,
        uint256 dstGasLimit
    ) public view returns (uint256) {
        return
            IConceroRouter(i_conceroRouter).getMessageFee(
                dstChainSelector,
                false, // shouldFinaliseSrc
                address(0), // feeToken (native)
                ConceroTypes.EvmDstChainData({
                    receiver: dstPool,
                    gasLimit: BRIDGE_GAS_OVERHEAD + dstGasLimit
                })
            );
    }
}
