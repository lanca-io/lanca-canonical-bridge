// SPDX-License-Identifier: MIT
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {ILancaCanonicalBridgeL1} from "../interfaces/ILancaCanonicalBridgeL1.sol";
import {
    LancaCanonicalBridgeBase,
    ILancaCanonicalBridgeClient
} from "./LancaCanonicalBridgeBase.sol";
import {BridgeCodec} from "../common/libraries/BridgeCodec.sol";
import {CommonErrors} from "@concero/v2-contracts/contracts/common/CommonErrors.sol";
import {IConceroRouter} from "@concero/v2-contracts/contracts/interfaces/IConceroRouter.sol";
import {ILancaCanonicalBridgePool} from "../interfaces/ILancaCanonicalBridgePool.sol";
import {MessageCodec} from "@concero/v2-contracts/contracts/common/libraries/MessageCodec.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts-v5/utils/ReentrancyGuard.sol";
import {Storage as s} from "./libraries/Storage.sol";

/// @title LancaCanonicalBridgeL1
/// @notice L1-side canonical bridge for USDC that coordinates liquidity pools and remote L2 bridges.
/// @dev
/// - Uses per-chain pools to custody USDC for each destination chain.
/// - Sends Concero messages to destination bridges and releases liquidity on inbound messages.
/// - Enforces rate limits and uses ADMIN role for configuration.
contract LancaCanonicalBridgeL1 is ILancaCanonicalBridgeL1, LancaCanonicalBridgeBase {
    using BridgeCodec for bytes32;
    using BridgeCodec for bytes;
    using MessageCodec for bytes;
    using s for s.L1Bridge;

    error InvalidDstBridge();
    error PoolNotFound(uint24 dstChainSelector);
    error PoolAlreadyExists(uint24 dstChainSelector);
    error DstBridgeAlreadyExists(uint24 dstChainSelector);

    constructor(
        address conceroRouter,
        address usdcAddress
    ) LancaCanonicalBridgeBase(usdcAddress, conceroRouter) {}

    /* ------- Main Functions ------- */

    /// @inheritdoc ILancaCanonicalBridgeL1
    function sendToken(
        uint256 tokenAmount,
        uint24 dstChainSelector,
        bytes calldata dstChainData,
        bytes calldata payload
    ) external payable returns (bytes32 messageId) {
        require(tokenAmount > 0, CommonErrors.InvalidAmount());

        s.L1Bridge storage s_bridge = s.l1Bridge();

        address pool = s_bridge.pools[dstChainSelector];
        bytes32 dstBridge = s_bridge.dstBridges[dstChainSelector];
        require(pool != address(0), PoolNotFound(dstChainSelector));
        require(dstBridge != bytes32(0), InvalidDstBridge());

        _consumeRate(dstChainSelector, tokenAmount, true);

        ILancaCanonicalBridgePool(pool).deposit(msg.sender, tokenAmount);

        messageId = _sendMessage(tokenAmount, dstChainSelector, payload, dstChainData, dstBridge);

        emit TokenSent(messageId, dstChainSelector, dstChainData, msg.sender, tokenAmount);
    }

    function _conceroReceive(bytes calldata messageReceipt) internal override {
        (address sender, ) = messageReceipt.evmSrcChainData();
        uint24 srcChainSelector = messageReceipt.srcChainSelector();

        require(sender == getBridgeAddress(srcChainSelector).toAddress(), InvalidBridgeSender());

        address pool = getPool(srcChainSelector);
        require(pool != address(0), PoolNotFound(srcChainSelector));

        bytes calldata messageData = messageReceipt.calldataPayload();
        bytes32 messageId = keccak256(messageReceipt);

        (
            bytes32 tokenSender,
            uint256 tokenAmount,
            bytes calldata dstChainData,
            bytes memory payload
        ) = messageData.decodeBridgeData();

        (address tokenReceiver, uint32 dstGasLimit) = dstChainData.decodeEvmDstChainData();

        _consumeRate(srcChainSelector, tokenAmount, false);

        bool shouldCallHook = _validateBridgeParams(dstGasLimit, tokenReceiver, payload);

        ILancaCanonicalBridgePool(pool).withdraw(tokenReceiver, tokenAmount);

        if (shouldCallHook) {
            ILancaCanonicalBridgeClient(tokenReceiver).lancaCanonicalBridgeReceive(
                messageId,
                srcChainSelector,
                tokenSender,
                tokenAmount,
                payload
            );
        }

        emit BridgeDelivered(messageId, tokenAmount);
    }

    /* ------- Admin Functions ------- */

    function addPools(
        uint24[] calldata dstChainSelectors,
        address[] calldata pools
    ) external onlyRole(ADMIN) {
        require(dstChainSelectors.length == pools.length, CommonErrors.LengthMismatch());

        s.L1Bridge storage l1BridgeStorage = s.l1Bridge();

        for (uint256 i = 0; i < dstChainSelectors.length; i++) {
            require(
                l1BridgeStorage.pools[dstChainSelectors[i]] == address(0),
                PoolAlreadyExists(dstChainSelectors[i])
            );
            l1BridgeStorage.pools[dstChainSelectors[i]] = pools[i];
        }
    }

    function addDstBridges(
        uint24[] calldata dstChainSelectors,
        bytes32[] calldata dstBridges
    ) external onlyRole(ADMIN) {
        require(dstChainSelectors.length == dstBridges.length, CommonErrors.LengthMismatch());

        s.L1Bridge storage s_l1BridgeStorage = s.l1Bridge();

        for (uint256 i = 0; i < dstChainSelectors.length; i++) {
            require(
                s_l1BridgeStorage.dstBridges[dstChainSelectors[i]] == bytes32(0),
                DstBridgeAlreadyExists(dstChainSelectors[i])
            );
            s_l1BridgeStorage.dstBridges[dstChainSelectors[i]] = dstBridges[i];
        }
    }

    function removePools(uint24[] calldata dstChainSelectors) external onlyRole(ADMIN) {
        s.L1Bridge storage s_l1BridgeStorage = s.l1Bridge();
        for (uint256 i = 0; i < dstChainSelectors.length; i++) {
            delete s_l1BridgeStorage.pools[dstChainSelectors[i]];
        }
    }

    function removeDstBridges(uint24[] calldata dstChainSelectors) external onlyRole(ADMIN) {
        s.L1Bridge storage s_l1BridgeStorage = s.l1Bridge();
        for (uint256 i = 0; i < dstChainSelectors.length; i++) {
            delete s_l1BridgeStorage.dstBridges[dstChainSelectors[i]];
        }
    }

    /* ------- View Functions ------- */

    function getPool(uint24 dstChainSelector) public view returns (address) {
        return s.l1Bridge().pools[dstChainSelector];
    }

    function getBridgeAddress(uint24 dstChainSelector) public view returns (bytes32) {
        return s.l1Bridge().dstBridges[dstChainSelector];
    }

    /// @inheritdoc ILancaCanonicalBridgeL1
    function getBridgeNativeFee(
        uint256 /* tokenAmount */,
        uint24 dstChainSelector,
        bytes calldata dstChainData,
        bytes calldata payload
    ) external view returns (uint256) {
        return
            _getBridgeNativeFee(
                dstChainSelector,
                dstChainData,
                payload,
                s.l1Bridge().dstBridges[dstChainSelector]
            );
    }
}
