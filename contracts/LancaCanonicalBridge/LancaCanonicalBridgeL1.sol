// SPDX-License-Identifier: MIT
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {ReentrancyGuard} from "@openzeppelin/contracts-v5/utils/ReentrancyGuard.sol";

import {CommonErrors} from "@concero/v2-contracts/contracts/common/CommonErrors.sol";

import {
    LancaCanonicalBridgeBase,
    ILancaCanonicalBridgeClient
} from "./LancaCanonicalBridgeBase.sol";
import {Storage as s} from "./libraries/Storage.sol";
import {ILancaCanonicalBridgePool} from "../interfaces/ILancaCanonicalBridgePool.sol";

import {IConceroRouter} from "@concero/v2-contracts/contracts/interfaces/IConceroRouter.sol";
import {MessageCodec} from "@concero/v2-contracts/contracts/common/libraries/MessageCodec.sol";

contract LancaCanonicalBridgeL1 is LancaCanonicalBridgeBase, ReentrancyGuard {
    using s for s.L1Bridge;
    using MessageCodec for IConceroRouter.MessageRequest;
    using MessageCodec for bytes;

    struct ValidatorLibs {
        address[] validatorLibs;
        bytes[] validatorConfigs;
        bool[] isAllowed;
        uint256 requiredValidatorsCount;
    }

    error InvalidDstBridge();
    error PoolNotFound(uint24 dstChainSelector);
    error PoolAlreadyExists(uint24 dstChainSelector);
    error DstBridgeAlreadyExists(uint24 dstChainSelector);

    constructor(
        address conceroRouter,
        address usdcAddress,
        address rateLimitAdmin
    ) LancaCanonicalBridgeBase(usdcAddress, rateLimitAdmin, conceroRouter) {}

    /* ------- Main Functions ------- */

    function sendToken(
        address tokenReceiver,
        uint256 tokenAmount,
        uint24 dstChainSelector,
        uint256 dstGasLimit,
        bytes calldata dstCallData
    ) external payable nonReentrant returns (bytes32 messageId) {
        require(tokenAmount > 0, CommonErrors.InvalidAmount());

        s.L1Bridge storage bridge = s.l1Bridge();

        address pool = bridge.pools[dstChainSelector];
        address dstBridge = bridge.dstBridges[dstChainSelector];
        require(pool != address(0), PoolNotFound(dstChainSelector));
        require(dstBridge != address(0), InvalidDstBridge());

        _consumeRate(dstChainSelector, tokenAmount, true);

        ILancaCanonicalBridgePool(pool).deposit(msg.sender, tokenAmount);

        {
            address relayerLib = bridge.relayerLibs[dstChainSelector];
            bytes memory relayerConfig = bridge.relayerConfigs[dstChainSelector];
            address[] memory validatorLibs = bridge.validatorLibs[dstChainSelector];
            bytes[] memory validatorConfigs = bridge.validatorConfigs[dstChainSelector];

            messageId = _sendMessage(
                tokenReceiver,
                tokenAmount,
                dstChainSelector,
                dstGasLimit,
                dstCallData,
                dstBridge,
                relayerLib,
                relayerConfig,
                validatorLibs,
                validatorConfigs
            );
        }

        emit TokenSent(messageId, msg.sender, tokenReceiver, dstChainSelector, tokenAmount);
    }

    function _conceroReceive(bytes calldata messageReceipt) internal override nonReentrant {
        (address sender, ) = messageReceipt.evmSrcChainData();
        uint24 srcChainSelector = messageReceipt.srcChainSelector();

        require(sender == getBridgeAddress(srcChainSelector), InvalidBridgeSender());

        address pool = s.l1Bridge().pools[srcChainSelector];
        require(pool != address(0), PoolNotFound(srcChainSelector));

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
        ILancaCanonicalBridgePool(pool).withdraw(tokenReceiver, tokenAmount);

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

    /* ------- Admin Functions ------- */

    function addPools(
        uint24[] calldata dstChainSelectors,
        address[] calldata pools
    ) external onlyOwner {
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
        address[] calldata dstBridges
    ) external onlyOwner {
        require(dstChainSelectors.length == dstBridges.length, CommonErrors.LengthMismatch());

        s.L1Bridge storage l1BridgeStorage = s.l1Bridge();

        for (uint256 i = 0; i < dstChainSelectors.length; i++) {
            require(
                l1BridgeStorage.dstBridges[dstChainSelectors[i]] == address(0),
                DstBridgeAlreadyExists(dstChainSelectors[i])
            );
            l1BridgeStorage.dstBridges[dstChainSelectors[i]] = dstBridges[i];
        }
    }

    function removePools(uint24[] calldata dstChainSelectors) external onlyOwner {
        s.L1Bridge storage l1BridgeStorage = s.l1Bridge();
        for (uint256 i = 0; i < dstChainSelectors.length; i++) {
            delete l1BridgeStorage.pools[dstChainSelectors[i]];
        }
    }

    function removeDstBridges(uint24[] calldata dstChainSelectors) external onlyOwner {
        s.L1Bridge storage l1BridgeStorage = s.l1Bridge();
        for (uint256 i = 0; i < dstChainSelectors.length; i++) {
            delete l1BridgeStorage.dstBridges[dstChainSelectors[i]];
        }
    }

    function setRelayerLib(
        uint24 dstChainSelector,
        address relayerLib,
        bytes calldata relayerConfig,
        bool isAllowed
    ) external onlyOwner {
        s.L1Bridge storage l1BridgeStorage = s.l1Bridge();

        l1BridgeStorage.relayerLibs[dstChainSelector] = relayerLib;
        l1BridgeStorage.relayerConfigs[dstChainSelector] = relayerConfig;

        _setIsRelayerAllowed(relayerLib, isAllowed);
    }

    function setValidatorLibs(
        uint24[] calldata dstChainSelectors,
        ValidatorLibs[] memory validatorLibs
    ) external onlyOwner {
        require(dstChainSelectors.length == validatorLibs.length, CommonErrors.LengthMismatch());

        s.L1Bridge storage l1BridgeStorage = s.l1Bridge();

        for (uint256 i = 0; i < dstChainSelectors.length; i++) {
            l1BridgeStorage.validatorLibs[dstChainSelectors[i]] = validatorLibs[i].validatorLibs;
            l1BridgeStorage.validatorConfigs[dstChainSelectors[i]] = validatorLibs[i]
                .validatorConfigs;

            _setRequiredValidatorsCount(validatorLibs[i].requiredValidatorsCount);

            for (uint256 j = 0; j < validatorLibs[i].validatorLibs.length; j++) {
                _setIsValidatorAllowed(
                    validatorLibs[i].validatorLibs[j],
                    validatorLibs[i].isAllowed[j]
                );
            }
        }
    }

    /* ------- View Functions ------- */

    function getPool(uint24 dstChainSelector) external view returns (address) {
        return s.l1Bridge().pools[dstChainSelector];
    }

    function getBridgeAddress(uint24 dstChainSelector) public view returns (address) {
        return s.l1Bridge().dstBridges[dstChainSelector];
    }

    function getBridgeNativeFee(
        uint24 dstChainSelector,
        uint256 dstGasLimit
    ) external view returns (uint256) {
        s.L1Bridge storage bridge = s.l1Bridge();

        return
            _getBridgeNativeFee(
                dstChainSelector,
                getBridgeAddress(dstChainSelector),
                dstGasLimit,
                bridge.relayerLibs[dstChainSelector],
                bridge.relayerConfigs[dstChainSelector],
                bridge.validatorLibs[dstChainSelector],
                bridge.validatorConfigs[dstChainSelector]
            );
    }
}
