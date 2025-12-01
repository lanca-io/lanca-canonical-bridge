// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

library BridgeCodec {
    error PayloadToBig();
    error DstChainDataToBig();

    uint8 internal constant VERSION = 1;

    uint8 internal constant BYTES32_LENGTH_BYTES = 32;
    uint8 internal constant UINT24_LENGTH_BYTES = 3;

    uint8 internal constant SENDER_OFFSET = 1;
    uint8 internal constant AMOUNT_OFFSET = SENDER_OFFSET + BYTES32_LENGTH_BYTES;
    uint8 internal constant DST_CHAIN_DATA_OFFSET = AMOUNT_OFFSET + BYTES32_LENGTH_BYTES;

    function toAddress(bytes32 addr) internal pure returns (address) {
        return address(bytes20(addr));
    }

    function toBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(bytes20(addr));
    }

    /// @notice Encodes bridge data into a compact byte array.
    /// @dev
    /// Layout:
    /// - [0:1]      VERSION (uint8)
    /// - [1:33]     sender (bytes32, address)
    /// - [33:65]    amount (uint256, 32 bytes)
    /// - [65:68]    dstChainData length (uint24)
    /// - [68:..]    dstChainData bytes
    /// - [..:..+3]  payload length (uint24)
    /// - [..]       payload bytes
    ///
    /// Requirements:
    /// - `payload.length` must fit into `uint24`.
    /// - `dstChainData.length` must fit into `uint24`.
    ///
    /// @param sender Address of the original token sender.
    /// @param amount Amount of tokens associated with the bridge operation.
    /// @param dstChainData ABI-encoded destination chain data (e.g. receiver, gas limit).
    /// @param payload Additional arbitrary payload forwarded to the destination.
    /// @return Encoded bridge data as bytes.
    function encodeBridgeData(
        address sender,
        uint256 amount,
        bytes memory dstChainData,
        bytes memory payload
    ) internal pure returns (bytes memory) {
        require(payload.length <= type(uint24).max, PayloadToBig());
        require(dstChainData.length <= type(uint24).max, DstChainDataToBig());

        return
            abi.encodePacked(
                VERSION,
                toBytes32(sender),
                amount,
                uint24(dstChainData.length),
                dstChainData,
                uint24(payload.length),
                payload
            );
    }

    // DECODERS

    /// @notice Decodes bridge data from an encoded byte array.
    /// @dev
    /// Expects the layout produced by {encodeBridgeData}.
    /// Returns:
    /// - sender as `bytes32`
    /// - amount as `uint256`
    /// - `dstChainData` as a calldata slice
    /// - `payload` as a memory copy
    ///
    /// The version byte is currently ignored and assumed to be `VERSION`.
    ///
    /// @param data Encoded bridge data bytes.
    /// @return sender Encoded sender address as `bytes32`.
    /// @return amount Decoded token amount.
    /// @return dstChainData Calldata slice containing the destination chain data.
    /// @return payload Decoded payload as a bytes array in memory.
    function decodeBridgeData(
        bytes calldata data
    ) internal pure returns (bytes32, uint256, bytes calldata, bytes memory) {
        uint24 dstChainDataLength = uint24(
            bytes3(data[DST_CHAIN_DATA_OFFSET:DST_CHAIN_DATA_OFFSET + UINT24_LENGTH_BYTES])
        );
        uint24 dstChainDataEnd = DST_CHAIN_DATA_OFFSET + dstChainDataLength + UINT24_LENGTH_BYTES;

        return (
            bytes32(data[SENDER_OFFSET:SENDER_OFFSET + BYTES32_LENGTH_BYTES]),
            uint256(bytes32(data[AMOUNT_OFFSET:AMOUNT_OFFSET + BYTES32_LENGTH_BYTES])),
            data[DST_CHAIN_DATA_OFFSET + UINT24_LENGTH_BYTES:dstChainDataEnd],
            data[dstChainDataEnd + UINT24_LENGTH_BYTES:]
        );
    }
}
