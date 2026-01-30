// SPDX-License-Identifier: MIT
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

interface ILancaCanonicalBridgeL1 {
    /// @notice Sends tokens from L1 to a destination chain using the configured pool and destination bridge.
    /// @dev
    /// - Checks that the token amount is non-zero.
    /// - Looks up the configured pool and destination bridge for `dstChainSelector`.
    /// - Consumes outbound rate limit for the given destination chain.
    /// - Deposits tokens into the chain-specific pool.
    /// - Constructs and sends a Concero message via `_sendMessage`.
    /// @param tokenAmount Amount of tokens (in smallest units) to bridge out of L1.
    /// @param dstChainSelector Chain selector of the destination chain.
    /// @param dstChainData ABI-encoded destination chain data (receiver, gas limit, etc.).
    /// @param payload Optional arbitrary payload to be forwarded to the receiver hook on the destination chain.
    /// @return messageId Unique identifier of the outbound bridge message.
    function sendToken(
        uint256 tokenAmount,
        uint24 dstChainSelector,
        bytes calldata dstChainData,
        bytes calldata payload
    ) external payable returns (bytes32 messageId);

    /// @notice Returns the estimated native fee required to perform a bridge operation from L1.
    /// @dev
    /// - The `tokenAmount` parameter is not used for fee calculation in this implementation.
    /// - Delegates to `_getBridgeNativeFee` from the base contract using the configured destination bridge.
    /// @param dstChainSelector Chain selector of the destination chain.
    /// @param dstChainData ABI-encoded destination chain data (receiver, gas limit, etc.).
    /// @param payload Additional payload that will be attached to the bridge message.
    /// @return Estimated native token fee required to send the message via Concero.
    function getBridgeNativeFee(
        uint256 /* tokenAmount */,
        uint24 dstChainSelector,
        bytes calldata dstChainData,
        bytes calldata payload
    ) external view returns (uint256);
}
