// SPDX-License-Identifier: MIT
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {ConceroOwnable} from "@concero/messaging-contracts-v2/contracts/common/ConceroOwnable.sol";

import {IFiatTokenV1} from "../interfaces/IFiatTokenV1.sol";
import {ILancaCanonicalBridgePool} from "../interfaces/ILancaCanonicalBridgePool.sol";

contract LancaCanonicalBridgePool is ILancaCanonicalBridgePool, Initializable, ConceroOwnable {
    IFiatTokenV1 private s_usdc;
    uint24 private s_dstChainSelector;

    function initialize(address usdcAddress, uint24 dstChainSelector) external initializer {
        s_usdc = IFiatTokenV1(usdcAddress);
        s_dstChainSelector = dstChainSelector;
    }

    function withdraw(address to, uint256 amount) external onlyOwner returns (bool) {
        // TODO: add limit?
        return s_usdc.transfer(to, amount);
    }

    function burnLockedUSDC() external onlyOwner {
        s_usdc.burn(s_usdc.balanceOf(address(this)));
    }

    function getPoolInfo() external view returns (uint24 dstChainSelector, uint256 lockedUSDC) {
        dstChainSelector = s_dstChainSelector;
        lockedUSDC = s_usdc.balanceOf(address(this));
    }
}
