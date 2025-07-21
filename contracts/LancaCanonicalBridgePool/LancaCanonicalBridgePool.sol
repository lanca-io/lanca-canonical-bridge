// SPDX-License-Identifier: MIT
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {CommonErrors} from "@concero/messaging-contracts-v2/contracts/common/CommonErrors.sol";

import {ILancaCanonicalBridgePool} from "../interfaces/ILancaCanonicalBridgePool.sol";

contract LancaCanonicalBridgePool is ILancaCanonicalBridgePool {
    using SafeERC20 for IERC20;

    IERC20 private immutable i_usdc;
    address public immutable i_lancaCanonicalBridgeL1;
    uint24 private immutable i_dstChainSelector;

    modifier onlyLancaCanonicalBridge() {
        require(msg.sender == i_lancaCanonicalBridgeL1, CommonErrors.Unauthorized());
        _;
    }

    constructor(address usdcAddress, address lancaCanonicalBridge, uint24 dstChainSelector) {
        i_usdc = IERC20(usdcAddress);
        i_lancaCanonicalBridgeL1 = lancaCanonicalBridge;
        i_dstChainSelector = dstChainSelector;
    }

    function deposit(address from, uint256 amount) external onlyLancaCanonicalBridge {
        i_usdc.safeTransferFrom(from, address(this), amount);
    }

    function withdraw(address to, uint256 amount) external onlyLancaCanonicalBridge {
        i_usdc.safeTransfer(to, amount);
    }

    function getPoolInfo() external view returns (uint24 dstChainSelector, uint256 lockedUSDC) {
        dstChainSelector = i_dstChainSelector;
        lockedUSDC = i_usdc.balanceOf(address(this));
    }
}
