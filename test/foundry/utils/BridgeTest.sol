// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {Test} from "forge-std/src/Test.sol";

import {BaseScript} from "../scripts/BaseScript.s.sol";
import {IConceroRouter} from "@concero/v2-contracts/contracts/interfaces/IConceroRouter.sol";

import {LancaCanonicalBridgeBase} from "contracts/LancaCanonicalBridge/LancaCanonicalBridgeBase.sol";

abstract contract BridgeTest is BaseScript, Test {
    function setUp() public virtual override {
        super.setUp();
    }

    function _encodeBridgeParams(
        address tokenSender,
        address tokenReceiver,
        uint256 tokenAmount,
        uint256 dstGasLimit,
        bytes memory dstCallData
    ) internal pure returns (bytes memory) {
        return
            abi.encode(tokenSender, tokenReceiver, tokenAmount, dstGasLimit, dstCallData);
    }

	function _getMessageId(
        uint24 dstChainSelector,
        bool shouldFinaliseSrc,
        address feeToken,
        bytes memory message
    ) internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(block.number, dstChainSelector, shouldFinaliseSrc, feeToken, message)
            );
    }
}
