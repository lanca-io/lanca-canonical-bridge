// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import {ILancaCanonicalBridgeClient} from "../interfaces/ILancaCanonicalBridgeClient.sol";

import {console} from "forge-std/src/Console.sol";

abstract contract LancaCanonicalBridgeClient is ILancaCanonicalBridgeClient, ERC165 {
    error InvalidLancaCanonicalBridge(address bridge);

    address internal immutable i_lancaCanonicalBridge;

    constructor(address lancaCanonicalBridge) {
        require(lancaCanonicalBridge != address(0), InvalidLancaCanonicalBridge(lancaCanonicalBridge));
        i_lancaCanonicalBridge = lancaCanonicalBridge;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return
            interfaceId == type(ILancaCanonicalBridgeClient).interfaceId ||
            super.supportsInterface(interfaceId);
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
