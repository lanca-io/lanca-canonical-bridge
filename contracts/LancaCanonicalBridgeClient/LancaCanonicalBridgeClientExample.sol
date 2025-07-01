// SPDX-License-Identifier: MIT
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {LancaCanonicalBridgeClient} from "./LancaCanonicalBridgeClient.sol";

import {console} from "forge-std/src/Console.sol";

contract LancaCanonicalBridgeClientExample is LancaCanonicalBridgeClient {
    address public token;
    address public tokenSender;
    uint256 public tokenAmount;
    string public testString;

    error TransferFailed();
    event TokensReceived(address token, address from, uint256 value, string testData);

    constructor(address lancaCanonicalBridge) LancaCanonicalBridgeClient(lancaCanonicalBridge) {}

    function _lancaCanonicalBridgeReceive(
        address _token,
        address _from,
        uint256 _value,
        bytes memory _data
    ) internal override {
        token = _token;
        tokenSender = _from;
        tokenAmount = _value;

        string memory _testString = abi.decode(_data, (string));
        testString = _testString;

        require(IERC20(_token).balanceOf(address(this)) >= _value, TransferFailed());
        emit TokensReceived(_token, _from, _value, _testString);
    }
}
