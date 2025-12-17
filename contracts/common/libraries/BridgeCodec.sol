// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

library BridgeCodec {
    error PayloadToBig();
    error DstChainDataToBig();

    uint8 internal constant VERSION = 1;

    uint8 internal constant BYTES32_LENGTH_BYTES = 32;
    uint8 internal constant UINT24_LENGTH_BYTES = 3;

    uint8 internal constant AMOUNT_OFFSET = 1;
    uint8 internal constant SENDER_OFFSET = AMOUNT_OFFSET + BYTES32_LENGTH_BYTES;
    uint8 internal constant RECEIVER_OFFSET = SENDER_OFFSET + BYTES32_LENGTH_BYTES;
    uint8 internal constant PAYLOAD_LENGTH_OFFSET = RECEIVER_OFFSET + BYTES32_LENGTH_BYTES;

    function toAddress(bytes32 addr) internal pure returns (address) {
        return address(bytes20(addr));
    }

    function toBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(bytes20(addr));
    }

    /// @notice Encodes bridge data into a compact byte array.
    /// @dev Layout:
    /// - [0]       : VERSION (uint8)
    /// - [1..33)   : amount (uint256, 32 bytes)
    /// - [33..65)  : sender (bytes32, 32 bytes)
    /// - [65..97)  : receiver (bytes32, 32 bytes)
    /// - [97..100) : payload length (uint24, 3 bytes)
    /// - [100..]   : payload bytes
    ///
    /// Requirements:
    /// - `payload.length` must fit into `uint24`.
    ///
    /// @param sender Original sender address on the source chain.
    /// @param receiver Receiver address on the destination chain.
    /// @param amount Amount of tokens associated with the bridge operation.
    /// @param payload Additional arbitrary payload forwarded to the destination.
    /// @return Encoded bridge data as bytes.
    function encodeBridgeData(
        address sender,
        address receiver,
        uint256 amount,
        bytes memory payload
    ) internal pure returns (bytes memory) {
        require(payload.length <= type(uint24).max, PayloadToBig());

        return
            abi.encodePacked(
                VERSION,
                amount,
                toBytes32(sender),
                toBytes32(receiver),
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
    /// - receiver as `bytes32`
    /// - `payload` as a memory copy
    ///
    /// The version byte is currently ignored and assumed to be `VERSION`.
    ///
    /// @param data Encoded bridge data bytes.
    /// @return amount Decoded token amount.
    /// @return sender Encoded sender address as `bytes32`.
    /// @return receiver Encoded receiver address as `bytes32`.
    /// @return payload Decoded payload as a bytes array in memory.
    function decodeBridgeData(
        bytes calldata data
    ) internal pure returns (uint256, bytes32, bytes32, bytes memory) {
        return (
            uint256(bytes32(data[AMOUNT_OFFSET:SENDER_OFFSET])),
            bytes32(data[SENDER_OFFSET:RECEIVER_OFFSET]),
            bytes32(data[RECEIVER_OFFSET:PAYLOAD_LENGTH_OFFSET]),
            data[PAYLOAD_LENGTH_OFFSET + UINT24_LENGTH_BYTES:]
        );
    }
}
