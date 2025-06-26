// SPDX-License-Identifier: MIT
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {CommonErrors} from "@concero/messaging-contracts-v2/contracts/common/CommonErrors.sol";

import {IFiatTokenV1} from "../interfaces/IFiatTokenV1.sol";
import {ILancaCanonicalBridgePool} from "../interfaces/ILancaCanonicalBridgePool.sol";

contract LancaCanonicalBridgePool is ILancaCanonicalBridgePool {
    address public immutable i_owner;
    IFiatTokenV1 private immutable i_usdc;
    uint24 private immutable i_dstChainSelector;

    modifier onlyOwner() {
        require(msg.sender == i_owner, CommonErrors.Unauthorized());
        _;
    }

    constructor(address usdcAddress, address lancaCanonicalBridge, uint24 dstChainSelector) {
        i_usdc = IFiatTokenV1(usdcAddress);
        i_dstChainSelector = dstChainSelector;
        i_owner = lancaCanonicalBridge;
    }

	function deposit(address from, uint256 amount) external onlyOwner returns (bool success) {
		success = i_usdc.transferFrom(from, address(this), amount);
	}

    function withdraw(address to, uint256 amount) external onlyOwner returns (bool success) {
        // TODO: add limit?
        success = i_usdc.transfer(to, amount);
    }

    function getPoolInfo() external view returns (uint24 dstChainSelector, uint256 lockedUSDC) {
        dstChainSelector = i_dstChainSelector;
        lockedUSDC = i_usdc.balanceOf(address(this));
    }
}
