// SPDX-License-Identifier: MIT
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {IERC165} from "@openzeppelin/contracts-v5/utils/introspection/IERC165.sol";

import {MessageCodec} from "@concero/v2-contracts/contracts/common/libraries/MessageCodec.sol";
import {CommonErrors} from "@concero/v2-contracts/contracts/common/CommonErrors.sol";
import {ConceroOwnable} from "@concero/v2-contracts/contracts/common/ConceroOwnable.sol";
import {ConceroClient} from "@concero/v2-contracts/contracts/ConceroClient/ConceroClient.sol";
import {IConceroRouter} from "@concero/v2-contracts/contracts/interfaces/IConceroRouter.sol";

import {ILancaCanonicalBridgeClient} from "../LancaCanonicalBridgeClient/LancaCanonicalBridgeClient.sol";
import {IFiatTokenV1} from "../interfaces/IFiatTokenV1.sol";
import {RateLimiter} from "./RateLimiter.sol";

import {BridgeCodec} from "../common/libraries/BridgeCodec.sol";
import {Storage as s} from "./libraries/Storage.sol";

abstract contract LancaCanonicalBridgeBase is ConceroClient, RateLimiter, ConceroOwnable {
    using BridgeCodec for bytes32;
    using s for s.Base;

    uint32 internal constant BRIDGE_GAS_OVERHEAD = 150_000;

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
    error RelayerLibAlreadySet(address relayerLib);
    error RelayerIsNotSet();
    error ValidatorAlreadySet(address validatorLib);
    error ValidatorIsNotSet();

    constructor(
        address usdcAddress,
        address rateLimitAdmin,
        address conceroRouter
    ) RateLimiter(rateLimitAdmin) ConceroClient(conceroRouter) {
        i_usdc = IFiatTokenV1(usdcAddress);
    }

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

        IConceroRouter.MessageRequest memory messageRequest = IConceroRouter.MessageRequest({
            dstChainSelector: dstChainSelector,
            srcBlockConfirmations: type(uint64).max,
            feeToken: address(0),
            dstChainData: _buildDstChainData(userDstChainData, dstBridge, payload.length),
            validatorLibs: validatorLibs,
            relayerLib: s_base.relayerLib,
            validatorConfigs: new bytes[](1),
            relayerConfig: new bytes(0),
            payload: BridgeCodec.encodeBridgeData(
                msg.sender,
                tokenAmount,
                userDstChainData,
                payload
            )
        });

        return IConceroRouter(i_conceroRouter).conceroSend{value: msg.value}(messageRequest);
    }

    function _buildDstChainData(
        bytes calldata userDstChainData,
        bytes32 dstBridge,
        uint256 payloadLength
    ) internal pure returns (bytes memory) {
        (, uint32 userDstChainGasLimit) = MessageCodec.decodeEvmDstChainData(userDstChainData);

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

    function _validateBridgeParams(
        uint32 dstGasLimit,
        address receiver,
        bytes memory payload
    ) internal view returns (bool) {
        bool shouldCallHook = !(dstGasLimit == 0 && payload.length == 0);

        if (shouldCallHook && !_isValidContractReceiver(receiver)) {
            revert InvalidConceroMessage();
        }

        return shouldCallHook;
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

    function _getBridgeNativeFee(
        uint24 dstChainSelector,
        bytes calldata userDstChainData,
        bytes calldata payload,
        bytes32 dstBridge
    ) internal view returns (uint256) {
        s.Base storage s_base = s.base();

        address[] memory validatorLibs = new address[](1);
        validatorLibs[0] = s_base.validatorLib;

        IConceroRouter.MessageRequest memory messageRequest = IConceroRouter.MessageRequest({
            dstChainSelector: dstChainSelector,
            srcBlockConfirmations: type(uint64).max,
            feeToken: address(0),
            dstChainData: _buildDstChainData(userDstChainData, dstBridge, payload.length),
            validatorLibs: validatorLibs,
            relayerLib: s_base.relayerLib,
            validatorConfigs: new bytes[](1),
            relayerConfig: new bytes(0),
            payload: BridgeCodec.encodeBridgeData(msg.sender, 1, userDstChainData, payload)
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

    function setRelayerLib(address relayerLib) external onlyOwner {
        s.Base storage s_base = s.base();

        require(relayerLib != address(0), CommonErrors.InvalidAddress());
        require(s_base.relayerLib == address(0), RelayerLibAlreadySet(s_base.relayerLib));

        s_base.relayerLib = relayerLib;
        _setIsRelayerAllowed(relayerLib, true);
    }

    function removeRelayerLib() external onlyOwner {
        s.Base storage s_base = s.base();

        address currentRelayer = s_base.relayerLib;
        require(currentRelayer != address(0), RelayerIsNotSet());

        _setIsRelayerAllowed(currentRelayer, false);

        s_base.relayerLib = address(0);
    }

    function setValidatorLib(address validatorLib) external onlyOwner {
        s.Base storage s_base = s.base();

        require(validatorLib != address(0), CommonErrors.InvalidAddress());
        require(s_base.validatorLib == address(0), ValidatorAlreadySet(s_base.validatorLib));

        s_base.validatorLib = validatorLib;

        _setRequiredValidatorsCount(1);
        _setIsValidatorAllowed(validatorLib, true);
    }

    function removeValidatorLib() external onlyOwner {
        s.Base storage s_base = s.base();

        address currentValidator = s_base.validatorLib;
        require(currentValidator != address(0), ValidatorIsNotSet());

        _setRequiredValidatorsCount(0);
        _setIsValidatorAllowed(currentValidator, false);

        s_base.validatorLib = address(0);
    }
}
