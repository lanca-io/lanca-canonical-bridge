// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {ILancaCanonicalBridgeClient} from "../interfaces/ILancaCanonicalBridgeClient.sol";

abstract contract LancaCanonicalBridgeClient is ILancaCanonicalBridgeClient {
    error InvalidLancaCanonicalBridge(address bridge);

    address internal immutable i_lancaCanonicalBridge;

    constructor(address lancaCanonicalBridge) {
        require(lancaCanonicalBridge != address(0), InvalidLancaCanonicalBridge(lancaCanonicalBridge));
        i_lancaCanonicalBridge = lancaCanonicalBridge;
    }

    function lancaCanonicalBridgeReceive(
        address token,
        address from,
        uint256 value,
        bytes memory data
    ) external returns (bytes4) {
        require(msg.sender == i_lancaCanonicalBridge, InvalidLancaCanonicalBridge(msg.sender));
        _lancaCanonicalBridgeReceive(token, from, value, data);

        return ILancaCanonicalBridgeClient.lancaCanonicalBridgeReceive.selector;
    }

    function _lancaCanonicalBridgeReceive(
        address token,
        address from,
        uint256 value,
        bytes memory data
    ) internal virtual;
}
