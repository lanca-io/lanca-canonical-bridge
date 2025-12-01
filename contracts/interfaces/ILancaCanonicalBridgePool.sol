// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

interface ILancaCanonicalBridgePool {
    /// @notice Deposits USDC into the pool from a user.
    /// @dev
    /// - Can only be called by the L1 canonical bridge.
    /// - Pulls tokens from `from` using `safeTransferFrom`, so `from` must approve this pool.
    /// @param from Address from which USDC will be transferred.
    /// @param amount Amount of USDC to deposit (in smallest units).
    function deposit(address from, uint256 amount) external;

    /// @notice Withdraws USDC from the pool to a recipient.
    /// @dev
    /// - Can only be called by the L1 canonical bridge.
    /// - Sends tokens directly from this contract to `to`.
    /// @param to Recipient address to receive USDC.
    /// @param amount Amount of USDC to withdraw (in smallest units).
    function withdraw(address to, uint256 amount) external;

    /// @notice Returns information about this pool.
    /// @dev
    /// - `dstChainSelector` identifies which destination chain this pool is tied to.
    /// - `lockedUsdc` is the current USDC balance held by this pool.
    /// @return dstChainSelector The destination chain selector served by this pool.
    /// @return lockedUsdc Current amount of USDC locked in the pool.
    function getPoolInfo() external view returns (uint24 dstChainSelector, uint256 lockedUsdc);
}
