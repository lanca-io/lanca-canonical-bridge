// SPDX-License-Identifier: MIT
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {LancaCanonicalBridgeClient} from "./LancaCanonicalBridgeClient.sol";

contract LancaCanonicalBridgeClientExample is LancaCanonicalBridgeClient {
    error TransferFailed();

    event TokensReceived(address token, address from, uint256 value, bytes data);

    constructor(address conceroRouter) LancaCanonicalBridgeClient(conceroRouter) {}

    function _lancaCanonicalBridgeReceive(
        address token,
        address from,
        uint256 value,
        bytes memory data
    ) internal override {
        require(IERC20(token).balanceOf(address(this)) >= value, TransferFailed());
        emit TokensReceived(token, from, value, data);
    }
}
