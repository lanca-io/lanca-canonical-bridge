// SPDX-License-Identifier: MIT
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {CommonErrors} from "@concero/messaging-contracts-v2/contracts/common/CommonErrors.sol";
import {Storage as s} from "./libraries/Storage.sol";

abstract contract RateLimiter {
    using s for s.RateLimits;

    error RateLimitExceeded(uint256 requested, uint256 availableVolume);
    error InvalidRateConfig(uint128 maxAmount, uint128 refillSpeed);

    event RateLimitSet(
        uint24 indexed dstChainSelector,
        bool isOutbound,
        uint128 maxAmount,
        uint128 refillSpeed
    );

    struct RateLimit {
        uint128 availableVolume; // Current available volume for transfers
        uint128 maxAmount; // Maximum allowed rate amount
        uint128 refillSpeed; // Amount added per second (refill rate)
        uint32 lastUpdate; // Last update timestamp for refill calculations
    }

    address public immutable i_rateLimitAdmin;

    modifier onlyRateLimitAdmin() {
        if (msg.sender != i_rateLimitAdmin) {
            revert CommonErrors.Unauthorized();
        }
        _;
    }

    constructor(address _rateLimitAdmin) {
        i_rateLimitAdmin = _rateLimitAdmin;
    }

    function _setRateLimit(
        uint24 dstChainSelector,
        uint128 maxAmount,
        uint128 refillSpeed,
        bool isOutbound
    ) internal {
        // Validate: refill speed cannot exceed max amount to prevent overflow
        // Only validate if maxAmount > 0, since 0 means transfers are disabled
        if (maxAmount > 0 && refillSpeed > maxAmount) {
            revert InvalidRateConfig(maxAmount, refillSpeed);
        }

        s.RateLimits storage limits = s.rateLimits();
        RateLimit storage rate = isOutbound
            ? limits.outboundRates[dstChainSelector]
            : limits.inboundRates[dstChainSelector];

        // Update available volume based on time elapsed since last update
        if (rate.lastUpdate > 0) {
            (uint128 newAvailable, uint32 newLastUpdate) = _refillRate(
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

    function _consumeRate(uint24 dstChainSelector, uint256 amount, bool isOutbound) internal {
        if (amount == 0) return;

        s.RateLimits storage limits = s.rateLimits();
        RateLimit storage rate = isOutbound
            ? limits.outboundRates[dstChainSelector]
            : limits.inboundRates[dstChainSelector];

        uint128 maxAmount = rate.maxAmount;
        uint32 lastUpdate = rate.lastUpdate;

        // If maxAmount = 0, transfers are disabled (soft pause)
        if (maxAmount == 0) {
            revert RateLimitExceeded(amount, 0);
        }

        // Update available volume with time-based refill
        (uint128 newAvailable, uint32 newLastUpdate) = _refillRate(
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

        // Write back only the changed values
        rate.availableVolume = newAvailable;
        if (newLastUpdate != lastUpdate) {
            rate.lastUpdate = newLastUpdate;
        }
    }

    function _refillRate(
        uint128 availableVolume,
        uint128 refillSpeed,
        uint128 maxAmount,
        uint32 lastUpdate
    ) internal view returns (uint128 newAvailable, uint32 newLastUpdate) {
        uint256 timeElapsed = block.timestamp - lastUpdate;
        if (timeElapsed == 0) {
            return (availableVolume, lastUpdate);
        }

        // Calculate amount to add based on elapsed time and refill rate
        uint256 toAdd = timeElapsed * refillSpeed;
        uint256 totalAvailable = availableVolume + toAdd;

        // Cap at maximum amount to prevent overflow and maintain limits
        newAvailable = uint128(totalAvailable > maxAmount ? maxAmount : totalAvailable);
        newLastUpdate = uint32(block.timestamp);
    }

    function getOutboundRateInfo(
        uint24 dstChainSelector
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
        RateLimit memory rate = s.rateLimits().outboundRates[dstChainSelector];
        return _getCurrentRateState(rate);
    }

    function getInboundRateInfo(
        uint24 dstChainSelector
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
        RateLimit memory rate = s.rateLimits().inboundRates[dstChainSelector];
        return _getCurrentRateState(rate);
    }

    function _getCurrentRateState(
        RateLimit memory rate
    )
        internal
        view
        returns (
            uint128 availableVolume,
            uint128 maxAmount,
            uint128 refillSpeed,
            uint32 lastUpdate,
            bool isActive
        )
    {
        // Simulate refill for active rates to show current available volume
        // isActive computed as maxAmount > 0
        bool rateIsActive = rate.maxAmount > 0;
        if (rateIsActive && rate.lastUpdate > 0) {
            uint256 timeElapsed = block.timestamp - rate.lastUpdate;
            uint256 toAdd = timeElapsed * rate.refillSpeed;
            uint256 newAvailable = rate.availableVolume + toAdd;
            // Apply maximum amount capping in simulation
            rate.availableVolume = uint128(
                newAvailable > rate.maxAmount ? rate.maxAmount : newAvailable
            );
        }

        return (
            rate.availableVolume,
            rate.maxAmount,
            rate.refillSpeed,
            rate.lastUpdate,
            rateIsActive
        );
    }
}
