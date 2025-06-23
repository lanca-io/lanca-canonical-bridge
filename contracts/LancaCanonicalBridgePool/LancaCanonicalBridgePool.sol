// SPDX-License-Identifier: MIT
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {ConceroOwnable} from "@concero/messaging-contracts-v2/contracts/common/ConceroOwnable.sol";

import {IFiatTokenV1} from "../interfaces/IFiatTokenV1.sol";
import {ILancaCanonicalBridgePool} from "../interfaces/ILancaCanonicalBridgePool.sol";

contract LancaCanonicalBridgePool is ILancaCanonicalBridgePool, ConceroOwnable {
    IFiatTokenV1 private immutable i_usdc;
    uint24 private immutable i_dstChainSelector;

    constructor(address usdcAddress, uint24 dstChainSelector) ConceroOwnable() {
        i_usdc = IFiatTokenV1(usdcAddress);
        i_dstChainSelector = dstChainSelector;
    }

    function withdraw(address to, uint256 amount) external onlyOwner returns (bool) {
        // TODO: add limit?
        return i_usdc.transfer(to, amount);
    }

    function burnLockedUSDC() external onlyOwner {
        i_usdc.burn(i_usdc.balanceOf(address(this)));
    }

    function getPoolInfo() external view returns (uint24 dstChainSelector, uint256 lockedUSDC) {
        dstChainSelector = i_dstChainSelector;
        lockedUSDC = i_usdc.balanceOf(address(this));
    }
}
