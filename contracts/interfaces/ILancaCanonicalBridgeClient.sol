// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

interface ILancaCanonicalBridgeClient {
    function lancaCanonicalBridgeReceive(
        bytes32 messageId,
        uint24 srcChainSelector,
        bytes32 from,
        uint256 value,
        bytes memory data
    ) external;
}
