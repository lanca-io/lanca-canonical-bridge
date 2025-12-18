// SPDX-License-Identifier: MIT
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {MessageCodec} from "@concero/v2-contracts/contracts/common/libraries/MessageCodec.sol";
import {CommonErrors} from "@concero/v2-contracts/contracts/common/CommonErrors.sol";
import {ConceroClient} from "@concero/v2-contracts/contracts/ConceroClient/ConceroClient.sol";
import {IConceroRouter} from "@concero/v2-contracts/contracts/interfaces/IConceroRouter.sol";
import {ILancaCanonicalBridgeClient} from "../LancaCanonicalBridgeClient/LancaCanonicalBridgeClient.sol";
import {IFiatTokenV1} from "../interfaces/IFiatTokenV1.sol";
import {RateLimiter} from "./RateLimiter.sol";
import {BridgeCodec} from "../common/libraries/BridgeCodec.sol";
import {Storage as s} from "./libraries/Storage.sol";

/// @title LancaCanonicalBridgeBase
/// @notice Base contract for Lanca canonical bridge logic shared across L1 and L2.
/// @dev
/// - Handles Concero message construction and fee estimation.
/// - Enforces rate limits via RateLimiter and access control via ConceroOwnable.
/// - Manages validator and relayer libraries used by the Concero router.
abstract contract LancaCanonicalBridgeBase is ConceroClient, RateLimiter {
    using ERC165Checker for address;
    using BridgeCodec for bytes32;
    using s for s.Base;

    uint32 internal constant BRIDGE_GAS_OVERHEAD = 150_000;
    bytes32 public constant ADMIN = keccak256("ADMIN");

    IFiatTokenV1 internal immutable i_usdc;

    event TokenSent(
        bytes32 indexed messageId,
        uint24 dstChainSelector,
        bytes dstChainData,
        address tokenSender,
        uint256 tokenAmount
    );
    event BridgeDelivered(bytes32 indexed messageId, uint256 tokenAmountWithFee);

    error InvalidBridgeSender();
    error InvalidDstGasLimitOrCallData();
    error InvalidConceroMessage();
    error InvalidReceiver();
    error RelayerLibAlreadySet(address relayerLib);
    error RelayerIsNotSet();
    error ValidatorAlreadySet(address validatorLib);
    error ValidatorIsNotSet();

    constructor(
        address usdcAddress,
        address conceroRouter
    ) RateLimiter() ConceroClient(conceroRouter) {
        i_usdc = IFiatTokenV1(usdcAddress);
    }

    function initialize(address admin) external initializer {
        __AccessControl_init();
        __AccessControl_init_unchained();

        _setRoleAdmin(ADMIN, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(RATE_LIMIT_ADMIN, ADMIN);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN, admin);
        _grantRole(RATE_LIMIT_ADMIN, admin);
    }

    /// @notice Builds and sends a Concero bridge message.
    /// @dev
    /// - Encodes bridge data including sender, token amount, destination chain data and payload.
    /// - Uses the stored validator and relayer libraries for message validation and delivery.
    /// - Forwards `msg.value` as the native fee to the Concero router.
    /// @param tokenAmount Amount of tokens being bridged (in smallest units).
    /// @param dstChainSelector Chain selector of the destination chain.
    /// @param payload Additional payload to be forwarded to the destination hook (if any).
    /// @param userDstChainData ABI-encoded destination chain data provided by the user.
    /// @param dstBridge Address (as bytes32) of the destination bridge contract.
    /// @return messageId Unique identifier of the created Concero message.
    function _sendMessage(
        uint256 tokenAmount,
        uint24 dstChainSelector,
        bytes calldata payload,
        bytes calldata userDstChainData,
        bytes32 dstBridge
    ) internal returns (bytes32 messageId) {
        s.Base storage s_base = s.base();

        address[] memory validatorLibs = new address[](1);
        validatorLibs[0] = s_base.validatorLib;

        IConceroRouter.MessageRequest memory messageRequest = _buildMessageRequest(
            s_base,
            tokenAmount,
            dstChainSelector,
            userDstChainData,
            payload,
            dstBridge
        );

        return IConceroRouter(i_conceroRouter).conceroSend{value: msg.value}(messageRequest);
    }

    function _buildMessageRequest(
        s.Base storage s_base,
        uint256 tokenAmount,
        uint24 dstChainSelector,
        bytes calldata userDstChainData,
        bytes calldata payload,
        bytes32 dstBridge
    ) private view returns (IConceroRouter.MessageRequest memory) {
        address[] memory validatorLibs = new address[](1);
        validatorLibs[0] = s_base.validatorLib;

        (address receiver, uint32 userDstChainGasLimit) = MessageCodec.decodeEvmDstChainData(
            userDstChainData
        );

        require(receiver != address(0), InvalidReceiver());

        return
            IConceroRouter.MessageRequest({
                dstChainSelector: dstChainSelector,
                srcBlockConfirmations: type(uint64).max,
                feeToken: address(0),
                dstChainData: _buildDstChainData(userDstChainGasLimit, dstBridge, payload.length),
                validatorLibs: validatorLibs,
                relayerLib: s_base.relayerLib,
                validatorConfigs: new bytes[](1),
                relayerConfig: new bytes(0),
                payload: BridgeCodec.encodeBridgeData(msg.sender, receiver, tokenAmount, payload)
            });
    }

    function _buildDstChainData(
        uint32 userDstChainGasLimit,
        bytes32 dstBridge,
        uint256 payloadLength
    ) internal pure returns (bytes memory) {
        require(
            (userDstChainGasLimit == 0 && payloadLength == 0) ||
                (userDstChainGasLimit > 0 && payloadLength > 0),
            InvalidDstGasLimitOrCallData()
        );

        return
            MessageCodec.encodeEvmDstChainData(
                dstBridge.toAddress(),
                BRIDGE_GAS_OVERHEAD + userDstChainGasLimit
            );
    }

    /// @notice Validates destination bridge parameters and determines whether a hook should be called.
    /// @dev
    /// - If `payload` indicate a hook call, the receiver must:
    ///   * be a contract, and
    ///   * support the `ILancaCanonicalBridgeClient` interface via ERC-165.
    /// @param receiver Address of the intended token receiver / hook target.
    /// @param payload Arbitrary payload that might be passed to the receiver.
    /// @return shouldCallHook True if the bridge should invoke the receiver hook on destination.
    function _validateBridgeParams(
        address receiver,
        bytes memory payload
    ) internal view returns (bool) {
        bool shouldCallHook = !(payload.length == 0);

        if (shouldCallHook && !_isValidContractReceiver(receiver)) {
            revert InvalidConceroMessage();
        }

        return shouldCallHook;
    }

    function _isValidContractReceiver(address tokenReceiver) internal view returns (bool) {
        if (
            tokenReceiver.code.length == 0 ||
            !tokenReceiver.supportsInterface(type(ILancaCanonicalBridgeClient).interfaceId)
        ) {
            return false;
        }

        return true;
    }

    function _getBridgeNativeFee(
        uint24 dstChainSelector,
        bytes calldata userDstChainData,
        bytes calldata payload,
        bytes32 dstBridge
    ) internal view returns (uint256) {
        s.Base storage s_base = s.base();

        address[] memory validatorLibs = new address[](1);
        validatorLibs[0] = s_base.validatorLib;

        (address receiver, uint32 userDstChainGasLimit) = MessageCodec.decodeEvmDstChainData(
            userDstChainData
        );

        IConceroRouter.MessageRequest memory messageRequest = IConceroRouter.MessageRequest({
            dstChainSelector: dstChainSelector,
            srcBlockConfirmations: type(uint64).max,
            feeToken: address(0),
            dstChainData: _buildDstChainData(userDstChainGasLimit, dstBridge, payload.length),
            validatorLibs: validatorLibs,
            relayerLib: s_base.relayerLib,
            validatorConfigs: new bytes[](1),
            relayerConfig: new bytes(0),
            payload: BridgeCodec.encodeBridgeData(msg.sender, receiver, 1, payload)
        });

        return IConceroRouter(i_conceroRouter).getMessageFee(messageRequest);
    }

    /* ------- Getters ------- */

    function getRelayerLib() public view returns (address) {
        return s.base().relayerLib;
    }

    function getValidatorLib() public view returns (address) {
        return s.base().validatorLib;
    }

    /* ------- Admin Functions ------- */

    function setRelayerLib(address relayerLib) external onlyRole(ADMIN) {
        s.Base storage s_base = s.base();

        require(relayerLib != address(0), CommonErrors.InvalidAddress());
        require(s_base.relayerLib == address(0), RelayerLibAlreadySet(s_base.relayerLib));

        s_base.relayerLib = relayerLib;
        _setIsRelayerLibAllowed(relayerLib, true);
    }

    function removeRelayerLib() external onlyRole(ADMIN) {
        s.Base storage s_base = s.base();

        address currentRelayer = s_base.relayerLib;
        require(currentRelayer != address(0), RelayerIsNotSet());

        _setIsRelayerLibAllowed(currentRelayer, false);

        s_base.relayerLib = address(0);
    }

    function setValidatorLib(address validatorLib) external onlyRole(ADMIN) {
        s.Base storage s_base = s.base();

        require(validatorLib != address(0), CommonErrors.InvalidAddress());
        require(s_base.validatorLib == address(0), ValidatorAlreadySet(s_base.validatorLib));

        s_base.validatorLib = validatorLib;

        _setRequiredValidatorsCount(1);
        _setIsValidatorAllowed(validatorLib, true);
    }

    function removeValidatorLib() external onlyRole(ADMIN) {
        s.Base storage s_base = s.base();

        address currentValidator = s_base.validatorLib;
        require(currentValidator != address(0), ValidatorIsNotSet());

        _setRequiredValidatorsCount(0);
        _setIsValidatorAllowed(currentValidator, false);

        s_base.validatorLib = address(0);
    }
}
