// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {Test} from "forge-std/src/Test.sol";

import {BaseScript} from "../scripts/BaseScript.s.sol";
import {IConceroRouter} from "@concero/messaging-contracts-v2/contracts/interfaces/IConceroRouter.sol";

import {LancaCanonicalBridgeBase} from "contracts/LancaCanonicalBridge/LancaCanonicalBridgeBase.sol";

abstract contract BridgeTest is BaseScript, Test {
    function setUp() public virtual override {
        super.setUp();
    }

    function _encodeBridgeParams(
        address tokenSender,
        address tokenReceiver,
        uint256 tokenAmount,
        bool isTokenReceiverContract,
        bytes memory dstCallData
    ) internal pure returns (bytes memory) {
        if (isTokenReceiverContract) {
            return
                abi.encode(
                    uint8(LancaCanonicalBridgeBase.BridgeType.CONTRACT_TRANSFER),
                    abi.encode(tokenSender, tokenReceiver, tokenAmount, dstCallData)
                );
        } else {
            return
                abi.encode(
                    uint8(LancaCanonicalBridgeBase.BridgeType.EOA_TRANSFER),
                    abi.encode(tokenSender, tokenReceiver, tokenAmount)
                );
        }
    }
}
