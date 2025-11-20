// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IConceroRouter} from "@concero/v2-contracts/contracts/interfaces/IConceroRouter.sol";
import {MessageCodec} from "@concero/v2-contracts/contracts/common/libraries/MessageCodec.sol";

import {LancaCanonicalBridgeBase} from "contracts/LancaCanonicalBridge/LancaCanonicalBridgeBase.sol";

import {BaseTest} from "./BaseTest.sol";

abstract contract LCBTest is BaseTest {
    function _buildMessageRequest(
        bytes memory messagePayload,
        uint24 dstChainSelector,
        address dstBridge
    ) internal view returns (IConceroRouter.MessageRequest memory) {
        return
            _buildMessageRequest(
                messagePayload,
                dstChainSelector,
                dstBridge,
                300_000,
                type(uint64).max,
                address(0)
            );
    }

    function _buildMessageRequest(
        bytes memory payload,
        uint24 dstChainSelector,
        address dstBridge,
        uint32 dstChainGasLimit,
        uint64 srcBlockConfirmations,
        address feeToken
    ) internal view returns (IConceroRouter.MessageRequest memory) {
        address[] memory validatorLibs = new address[](1);
        validatorLibs[0] = s_validatorLib;

        return
            IConceroRouter.MessageRequest({
                dstChainSelector: dstChainSelector,
                srcBlockConfirmations: srcBlockConfirmations,
                feeToken: feeToken,
                dstChainData: MessageCodec.encodeEvmDstChainData(dstBridge, dstChainGasLimit),
                validatorLibs: validatorLibs,
                relayerLib: s_relayerLib,
                validatorConfigs: new bytes[](1),
                relayerConfig: new bytes(0),
                payload: payload
            });
    }

    function _setRelayerLib(address client) internal {
        vm.prank(s_deployer);
        LancaCanonicalBridgeBase(client).setIsRelayerLibAllowed(s_relayerLib, true);
    }

    function _setValidatorLibs(address client) internal {
        vm.prank(s_deployer);
        LancaCanonicalBridgeBase(client).setValidatorLib(s_validatorLib);
    }
}
