// SPDX-License-Identifier: MIT
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {ReentrancyGuard} from "@openzeppelin/contracts-v5/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts-v5/token/ERC20/utils/SafeERC20.sol";

import {CommonErrors} from "@concero/v2-contracts/contracts/common/CommonErrors.sol";

import {
    LancaCanonicalBridgeBase,
    ILancaCanonicalBridgeClient,
    ConceroClient
} from "./LancaCanonicalBridgeBase.sol";

contract LancaCanonicalBridge is LancaCanonicalBridgeBase, ReentrancyGuard {
    uint24 internal immutable i_dstChainSelector;
    address internal immutable i_lancaCanonicalBridgeL1;

    constructor(
        uint24 dstChainSelector,
        address conceroRouter,
        address usdcAddress,
        address lancaCanonicalBridgeL1,
        address rateLimitAdmin
    ) LancaCanonicalBridgeBase(usdcAddress, rateLimitAdmin) ConceroClient(conceroRouter) {
        i_dstChainSelector = dstChainSelector;
        i_lancaCanonicalBridgeL1 = lancaCanonicalBridgeL1;
    }

    /* ------- Main Functions ------- */

    function sendToken(
        address tokenReceiver,
        uint256 tokenAmount,
        uint256 dstGasLimit,
        bytes calldata dstCallData
    ) external payable nonReentrant returns (bytes32 messageId) {
        require(tokenAmount > 0, CommonErrors.InvalidAmount());

        _consumeRate(i_dstChainSelector, tokenAmount, true);

        SafeERC20.safeTransferFrom(i_usdc, msg.sender, address(this), tokenAmount);
        i_usdc.burn(tokenAmount);

        messageId = _sendMessage(
            tokenReceiver,
            tokenAmount,
            i_dstChainSelector,
            dstGasLimit,
            dstCallData,
            i_lancaCanonicalBridgeL1
        );

        emit TokenSent(messageId, msg.sender, tokenReceiver, tokenAmount);
    }

    function _conceroReceive(
        bytes32 messageId,
        uint24 srcChainSelector,
        bytes calldata sender,
        bytes calldata message
    ) internal override nonReentrant {
        require(abi.decode(sender, (address)) == i_lancaCanonicalBridgeL1, InvalidBridgeSender());

        (
            address tokenSender,
            address tokenReceiver,
            uint256 tokenAmount,
            uint256 dstGasLimit,
            bytes memory dstCallData
        ) = abi.decode(message, (address, address, uint256, uint256, bytes));

        bool shouldCallHook = !(dstGasLimit == 0 && dstCallData.length == 0);

        if (shouldCallHook && !_isValidContractReceiver(tokenReceiver)) {
            revert InvalidConceroMessage();
        }

        _consumeRate(srcChainSelector, tokenAmount, false);
        i_usdc.mint(tokenReceiver, tokenAmount);

        if (shouldCallHook) {
            ILancaCanonicalBridgeClient(tokenReceiver).lancaCanonicalBridgeReceive{
                gas: dstGasLimit
            }(messageId, srcChainSelector, tokenSender, tokenAmount, dstCallData);
        }

        emit BridgeDelivered(messageId, srcChainSelector, tokenSender, tokenReceiver, tokenAmount);
    }

    /* ------- View Functions ------- */

    function getBridgeNativeFee(uint256 dstGasLimit) external view returns (uint256) {
        return getBridgeNativeFee(i_dstChainSelector, i_lancaCanonicalBridgeL1, dstGasLimit);
    }
}
