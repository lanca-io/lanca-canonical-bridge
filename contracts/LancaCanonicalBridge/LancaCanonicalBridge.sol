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
import {Storage as s} from "./libraries/Storage.sol";

import {
    LancaCanonicalBridgeBase,
    ILancaCanonicalBridgeClient
} from "./LancaCanonicalBridgeBase.sol";

contract LancaCanonicalBridge is LancaCanonicalBridgeBase, ReentrancyGuard {
    using s for s.Bridge;

    uint24 internal immutable i_l1ChainSelector;
    address internal immutable i_lancaCanonicalBridgeL1;

    constructor(
        uint24 l1ChainSelector,
        address conceroRouter,
        address usdcAddress,
        address lancaCanonicalBridgeL1,
        address rateLimitAdmin
    ) LancaCanonicalBridgeBase(usdcAddress, rateLimitAdmin, conceroRouter) {
        i_l1ChainSelector = l1ChainSelector;
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

        s.Bridge storage bridge = s.bridge();

        _consumeRate(i_l1ChainSelector, tokenAmount, true);

        SafeERC20.safeTransferFrom(i_usdc, msg.sender, address(this), tokenAmount);
        i_usdc.burn(tokenAmount);

        messageId = _sendMessage(
            tokenReceiver,
            tokenAmount,
            i_l1ChainSelector,
            dstGasLimit,
            dstCallData,
            i_lancaCanonicalBridgeL1,
            bridge.relayerLib,
            bridge.relayerConfig,
            bridge.validatorLibs,
            bridge.validatorConfigs
        );

        emit TokenSent(messageId, msg.sender, tokenReceiver, i_l1ChainSelector, tokenAmount);
    }

    function _conceroReceive(bytes memory messageReceipt) internal override nonReentrant {
        (address sender, ) = messageReceipt.evmSrcChainData();
        uint24 srcChainSelector = messageReceipt.srcChainSelector();

        require(
            sender == i_lancaCanonicalBridgeL1 && srcChainSelector == i_l1ChainSelector,
            InvalidBridgeSender()
        );

        bytes memory message = messageReceipt.payload();

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

        bytes32 messageId = keccak256(messageReceipt);

        if (shouldCallHook) {
            ILancaCanonicalBridgeClient(tokenReceiver).lancaCanonicalBridgeReceive(
                messageId,
                srcChainSelector,
                tokenSender,
                tokenAmount,
                dstCallData
            );
        }

        emit BridgeDelivered(messageId, tokenAmount);
    }

    function setRelayerLib(address relayerLib, bytes calldata relayerConfig) external onlyOwner {
        s.Bridge storage bridge = s.bridge();

        bridge.relayerLib = relayerLib;
        bridge.relayerConfig = relayerConfig;
    }

    function setValidatorLibs(
        address[] calldata validatorLibs,
        bytes[] calldata validatorConfigs
    ) external onlyOwner {
        s.Bridge storage bridge = s.bridge();

        bridge.validatorLibs = validatorLibs;
        bridge.validatorConfigs = validatorConfigs;

        _setRequiredValidatorsCount(validatorLibs.length);

        for (uint256 i = 0; i < validatorLibs.length; i++) {
            _setIsValidatorAllowed(validatorLibs[i], true);
        }
    }

    /* ------- View Functions ------- */

    function getBridgeNativeFee(uint256 dstGasLimit) external view returns (uint256) {
        s.Bridge storage bridge = s.bridge();

        return
            _getBridgeNativeFee(
                i_l1ChainSelector,
                i_lancaCanonicalBridgeL1,
                dstGasLimit,
                bridge.relayerLib,
                bridge.relayerConfig,
                bridge.validatorLibs,
                bridge.validatorConfigs
            );
    }
}
