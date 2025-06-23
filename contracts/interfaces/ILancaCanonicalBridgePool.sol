// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

interface ILancaCanonicalBridgePool {
    function withdraw(address to, uint256 amount) external returns (bool);
    function burnLockedUSDC() external;
    function getPoolInfo() external view returns (uint24 dstChainSelector, uint256 lockedUSDC);
}
