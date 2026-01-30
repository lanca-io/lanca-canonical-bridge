// SPDX-License-Identifier: MIT
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

interface ILancaCanonicalBridge {
    /// @notice Sends tokens from this chain to the L1 canonical bridge.
    /// @dev
    /// - Consumes the outbound rate limit for the L1 chain.
    /// - Transfers USDC from the caller, burns it, and sends a bridge message to L1.
    /// @param tokenAmount Amount of USDC (in smallest units) to send to L1.
    /// @param dstChainData ABI-encoded destination chain data (e.g. receiver and gas limit).
    /// @param payload Additional arbitrary data forwarded to the receiver hook on the destination chain.
    /// @return messageId Unique identifier of the outbound bridge message.
    function sendToken(
        uint256 tokenAmount,
        bytes calldata dstChainData,
        bytes calldata payload
    ) external payable returns (bytes32 messageId);

    /// @notice Returns the estimated native fee required to perform a bridge operation.
    /// @dev
    /// - The `tokenAmount` is currently unused for fee calculation on this chain.
    /// @param dstChainSelector Chain selector of the destination chain.
    /// @param dstChainData ABI-encoded destination chain data (e.g. receiver and gas limit).
    /// @param payload Additional arbitrary data that will be attached to the bridge message.
    /// @return Estimated native token fee required to send the message.
    function getBridgeNativeFee(
        uint256 tokenAmount,
        uint24 dstChainSelector,
        bytes calldata dstChainData,
        bytes calldata payload
    ) external view returns (uint256);
}
