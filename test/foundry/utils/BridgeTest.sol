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

abstract contract BridgeTest is BaseScript, Test {
    function setUp() public virtual override {
        super.setUp();
    }

    function _encodeBridgeParams(
        address tokenSender,
        address tokenReceiver,
        uint256 tokenAmount,
        bool isContract,
        bytes memory dstCallData
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                abi.encode(tokenSender, tokenReceiver, tokenAmount),
                abi.encodePacked(isContract ? uint8(1) : uint8(0), dstCallData)
            );
    }
}
