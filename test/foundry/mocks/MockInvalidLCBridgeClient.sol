// SPDX-License-Identifier: MIT
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import {ILancaCanonicalBridgeClient} from "contracts/interfaces/ILancaCanonicalBridgeClient.sol";

contract MockInvalidLCBridgeClient is ERC165 {
    // Dummy state variable to prevent pure function warning
    bool private _dummy;

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return
            interfaceId == type(ILancaCanonicalBridgeClient).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function lancaCanonicalBridgeReceive(
        address /** token */,
        address /** from */,
        uint256 /** value */,
        bytes memory /** data */
    ) external {
        // Write dummy state to prevent pure function warning
        _dummy = false;
    }
}
