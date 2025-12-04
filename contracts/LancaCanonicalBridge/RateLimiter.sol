// SPDX-License-Identifier: MIT
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {CommonErrors} from "@concero/v2-contracts/contracts/common/CommonErrors.sol";
import {Storage as s} from "./libraries/Storage.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

/// @title RateLimiter
/// @notice Token transfer rate limiter for inbound and outbound bridge traffic per chain.
/// @dev
/// - Implements a token bucket–style rate limiting mechanism per `dstChainSelector`.
/// - Maintains separate limits for outbound and inbound directions.
abstract contract RateLimiter is AccessControlUpgradeable {
    using s for s.RateLimits;

    event RateLimitSet(
        uint24 indexed dstChainSelector,
        bool isOutbound,
        uint128 maxAmount,
        uint128 refillSpeed
    );

    error RateLimitExceeded(uint256 requested, uint256 availableVolume);
    error InvalidRateLimitConfig(uint128 maxAmount, uint128 refillSpeed);

    struct RateLimit {
        uint128 availableVolume; // Current available volume for transfers
        uint128 maxAmount; // Maximum allowed rate amount
        uint128 refillSpeed; // Amount added per second (refill rate)
        uint32 lastUpdate; // Last update timestamp for refill calculations
    }

    bytes32 public constant RATE_LIMIT_ADMIN = keccak256("RATE_LIMIT_ADMIN");

    /// @notice Configures or updates the rate limit for a specific chain and direction.
    /// @dev
    /// - If `maxAmount == 0`, transfers are effectively disabled (soft pause).
    /// - Ensures `refillSpeed <= maxAmount` (when `maxAmount > 0`) to avoid overflow.
    /// - Recalculates `availableVolume` based on elapsed time before applying new limits.
    /// - Caps `availableVolume` to `maxAmount` when reducing limits.
    /// @param dstChainSelector Chain selector the rate limit applies to.
    /// @param maxAmount Maximum bucket size (cap on available volume). `0` disables transfers.
    /// @param refillSpeed Refill amount per second, up to `maxAmount`.
    /// @param isOutbound True to configure outbound rate, false for inbound rate.
    function setRateLimit(
        uint24 dstChainSelector,
        uint128 maxAmount,
        uint128 refillSpeed,
        bool isOutbound
    ) external onlyRole(RATE_LIMIT_ADMIN) {
        // Validate: refill speed cannot exceed max amount to prevent overflow
        // Only validate if maxAmount > 0, since 0 means transfers are disabled
        if (maxAmount > 0 && refillSpeed > maxAmount) {
            revert InvalidRateLimitConfig(maxAmount, refillSpeed);
        }

        RateLimit storage rate = isOutbound
            ? s.rateLimits().outboundRates[dstChainSelector]
            : s.rateLimits().inboundRates[dstChainSelector];

        // Update available volume based on time elapsed since last update
        if (rate.lastUpdate > 0) {
            (uint128 newAvailable, uint32 newLastUpdate) = _getRefillRate(
                rate.availableVolume,
                rate.refillSpeed,
                rate.maxAmount,
                rate.lastUpdate
            );
            rate.availableVolume = newAvailable;
            rate.lastUpdate = newLastUpdate;
        }

        rate.maxAmount = maxAmount;
        rate.refillSpeed = refillSpeed;
        rate.lastUpdate = uint32(block.timestamp);

        // Security: Cap available volume to new max when reducing limits
        // Prevents bypass of new restrictions with previously accumulated amounts
        if (rate.availableVolume > maxAmount) {
            rate.availableVolume = maxAmount;
        }

        // Initialize available volume for first-time setup
        if (rate.availableVolume == 0 && maxAmount > 0) {
            rate.availableVolume = maxAmount;
        }

        emit RateLimitSet(dstChainSelector, isOutbound, maxAmount, refillSpeed);
    }

    /// @notice Consumes rate limit volume for a specific chain and direction.
    /// @dev
    /// - Recomputes `availableVolume` using `_getRefillRate` based on elapsed time.
    /// - Reverts with `RateLimitExceeded` if `amount` exceeds updated `availableVolume`.
    /// - If `maxAmount == 0`, the rate limit is treated as disabled and always reverts.
    /// @param dstChainSelector Chain selector the rate limit applies to.
    /// @param amount Amount to consume from the available volume.
    /// @param isOutbound True to consume from outbound bucket, false from inbound bucket.
    function _consumeRate(uint24 dstChainSelector, uint256 amount, bool isOutbound) internal {
        if (amount == 0) return;

        RateLimit storage rate = isOutbound
            ? s.rateLimits().outboundRates[dstChainSelector]
            : s.rateLimits().inboundRates[dstChainSelector];
        RateLimit storage oppositeRate = isOutbound
            ? s.rateLimits().inboundRates[dstChainSelector]
            : s.rateLimits().outboundRates[dstChainSelector];

        uint128 maxAmount = rate.maxAmount;
        uint32 lastUpdate = rate.lastUpdate;

        // If maxAmount = 0, transfers are disabled (soft pause)
        if (maxAmount == 0) {
            revert RateLimitExceeded(amount, 0);
        }

        // Update available volume with time-based refill
        (uint128 newAvailable, uint32 newLastUpdate) = _getRefillRate(
            rate.availableVolume,
            rate.refillSpeed,
            maxAmount,
            lastUpdate
        );

        // Enforce rate limit: revert if requested amount exceeds available
        if (newAvailable < amount) {
            revert RateLimitExceeded(amount, newAvailable);
        }

        // Consume the requested amount from available rate
        newAvailable -= uint128(amount);
        oppositeRate.availableVolume += uint128(amount);

        // Write back only the changed values
        rate.availableVolume = newAvailable;
        if (newLastUpdate != lastUpdate) {
            rate.lastUpdate = newLastUpdate;
        }
    }

    /// @notice Calculates the refilled available volume for a rate bucket.
    /// @dev
    /// - Uses `block.timestamp - lastUpdate` to compute the elapsed time.
    /// - Adds `timeElapsed * refillSpeed` to `availableVolume`, capped at `maxAmount`.
    /// @param availableVolume Current available volume before refill.
    /// @param refillSpeed Refill speed (tokens per second).
    /// @param maxAmount Maximum bucket capacity.
    /// @param lastUpdate Timestamp of the last update.
    /// @return newAvailable Updated available volume after applying refill.
    /// @return newLastUpdate Updated timestamp (current block timestamp).
    function _getRefillRate(
        uint128 availableVolume,
        uint128 refillSpeed,
        uint128 maxAmount,
        uint32 lastUpdate
    ) internal view returns (uint128 newAvailable, uint32 newLastUpdate) {
        uint32 timeElapsed = uint32(block.timestamp) - lastUpdate;
        if (timeElapsed == 0) {
            return (availableVolume, lastUpdate);
        }

        // Calculate amount to add based on elapsed time and refill rate
        uint256 toAdd = uint256(timeElapsed) * uint256(refillSpeed);
        uint256 totalAvailable = availableVolume + toAdd;

        // Cap at maximum amount to prevent overflow and maintain limits
        newAvailable = uint128(totalAvailable > maxAmount ? maxAmount : totalAvailable);
        newLastUpdate = uint32(block.timestamp);
    }

    /// @notice Returns the current rate limit information for a given chain and direction.
    /// @dev
    /// - Recomputes `availableVolume` at query time using `_getRefillRate`.
    /// - `isActive` is true when `maxAmount > 0` (non-paused).
    /// @param dstChainSelector Chain selector to query.
    /// @param isOutbound True to query the outbound bucket, false for inbound.
    /// @return availableVolume Updated available volume after refill.
    /// @return maxAmount Configured maximum bucket size.
    /// @return refillSpeed Configured refill speed (tokens per second).
    /// @return lastUpdate Effective last update timestamp after refill computation.
    /// @return isActive True if the limit is active (`maxAmount > 0`), false otherwise.
    function getRateInfo(
        uint24 dstChainSelector,
        bool isOutbound
    )
        public
        view
        returns (
            uint128 availableVolume,
            uint128 maxAmount,
            uint128 refillSpeed,
            uint32 lastUpdate,
            bool isActive
        )
    {
        RateLimit memory rate = isOutbound
            ? s.rateLimits().outboundRates[dstChainSelector]
            : s.rateLimits().inboundRates[dstChainSelector];

        isActive = rate.maxAmount > 0;

        (availableVolume, lastUpdate) = _getRefillRate(
            rate.availableVolume,
            rate.refillSpeed,
            rate.maxAmount,
            rate.lastUpdate
        );

        return (availableVolume, rate.maxAmount, rate.refillSpeed, lastUpdate, isActive);
    }
}
