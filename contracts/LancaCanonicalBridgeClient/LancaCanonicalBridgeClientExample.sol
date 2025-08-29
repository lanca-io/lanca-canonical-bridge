// SPDX-License-Identifier: MIT
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts-v5/token/ERC20/IERC20.sol";

import {LancaCanonicalBridgeClient} from "./LancaCanonicalBridgeClient.sol";

contract LancaCanonicalBridgeClientExample is LancaCanonicalBridgeClient {
	address public immutable usdc;

    bytes32 public messageId;
	uint24 public srcChainSelector;
    address public tokenSender;
    uint256 public tokenAmount;
    string public testString;


    error TransferFailed();
    event TokensReceived(bytes32 messageId, uint24 srcChainSelector, address tokenSender, uint256 tokenAmount, string testString);

    constructor(address lancaCanonicalBridge, address _usdc) LancaCanonicalBridgeClient(lancaCanonicalBridge) {
		usdc = _usdc;
	}

    function _lancaCanonicalBridgeReceive(
        bytes32 _messageId,
        uint24 _srcChainSelector,
        address _from,	
        uint256 _value,
        bytes memory _data
    ) internal override {
        messageId = _messageId;
        srcChainSelector = _srcChainSelector;
        tokenSender = _from;
        tokenAmount = _value;

        string memory _testString;
        if (_data.length > 0) {
            _testString = abi.decode(_data, (string));
        }
        testString = _testString;

        require(IERC20(usdc).balanceOf(address(this)) >= _value, TransferFailed());
        emit TokensReceived(_messageId, _srcChainSelector, _from, _value, _testString);
    }
}
