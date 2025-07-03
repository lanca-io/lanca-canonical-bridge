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

    error RateLimitExceeded(uint256 requested, uint256 available);

    event RateLimitOutboundConfigSet(
        uint24 dstChainSelector,
        uint32 period,
        uint128 maxAmountPerPeriod
    );
    event RateLimitInboundConfigSet(
        uint24 dstChainSelector,
        uint32 period,
        uint128 maxAmountPerPeriod
    );

    struct Config {
        uint128 used;
        uint128 maxAmountPerPeriod;
        uint32 period;
        uint32 lastReset;
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

    function setOutboundRateLimit(
        uint24 dstChainSelector,
        uint32 period,
        uint128 maxAmountPerPeriod
    ) public virtual {
        s.RateLimits storage rateLimits = s.rateLimits();

        rateLimits.outboundRateLimit[dstChainSelector].period = period;
        rateLimits.outboundRateLimit[dstChainSelector].maxAmountPerPeriod = maxAmountPerPeriod;
        rateLimits.outboundRateLimit[dstChainSelector].lastReset = uint32(block.timestamp);
        rateLimits.outboundRateLimit[dstChainSelector].used = 0;

        emit RateLimiter.RateLimitOutboundConfigSet(dstChainSelector, period, maxAmountPerPeriod);
    }

    function setInboundRateLimit(
        uint24 dstChainSelector,
        uint32 period,
        uint128 maxAmountPerPeriod
    ) public virtual {
        s.RateLimits storage rateLimits = s.rateLimits();

        rateLimits.inboundRateLimit[dstChainSelector].period = period;
        rateLimits.inboundRateLimit[dstChainSelector].maxAmountPerPeriod = maxAmountPerPeriod;
        rateLimits.inboundRateLimit[dstChainSelector].lastReset = uint32(block.timestamp);
        rateLimits.inboundRateLimit[dstChainSelector].used = 0;

        emit RateLimiter.RateLimitInboundConfigSet(dstChainSelector, period, maxAmountPerPeriod);
    }

    function getOutboundRateLimitInfo(
        uint24 dstChainSelector
    )
        public
        view
        returns (
            uint128 usedAmount,
            uint32 period,
            uint128 maxAmountPerPeriod,
            uint32 lastReset,
            uint256 availableAmount
        )
    {
        s.RateLimits storage rateLimits = s.rateLimits();

        usedAmount = rateLimits.outboundRateLimit[dstChainSelector].used;
        period = rateLimits.outboundRateLimit[dstChainSelector].period;
        maxAmountPerPeriod = rateLimits.outboundRateLimit[dstChainSelector].maxAmountPerPeriod;
        lastReset = rateLimits.outboundRateLimit[dstChainSelector].lastReset;

        availableAmount = _getAvailable(maxAmountPerPeriod, period, lastReset, usedAmount);
    }

    function getInboundRateLimitInfo(
        uint24 dstChainSelector
    )
        public
        view
        returns (
            uint128 usedAmount,
            uint32 period,
            uint128 maxAmountPerPeriod,
            uint32 lastReset,
            uint256 availableAmount
        )
    {
        s.RateLimits storage rateLimits = s.rateLimits();

        usedAmount = rateLimits.inboundRateLimit[dstChainSelector].used;
        period = rateLimits.inboundRateLimit[dstChainSelector].period;
        maxAmountPerPeriod = rateLimits.inboundRateLimit[dstChainSelector].maxAmountPerPeriod;
        lastReset = rateLimits.inboundRateLimit[dstChainSelector].lastReset;

        availableAmount = _getAvailable(maxAmountPerPeriod, period, lastReset, usedAmount);
    }

    function _checkOutboundRateLimit(uint24 dstChainSelector, uint256 amount) internal {
        s.RateLimits storage rateLimits = s.rateLimits();

        uint32 lastReset = rateLimits.outboundRateLimit[dstChainSelector].lastReset;
        uint128 used = rateLimits.outboundRateLimit[dstChainSelector].used;

        (uint32 newLastReset, uint128 newUsed) = _checkAndConsume(
            rateLimits.outboundRateLimit[dstChainSelector].lastReset,
            rateLimits.outboundRateLimit[dstChainSelector].period,
            rateLimits.outboundRateLimit[dstChainSelector].used,
            rateLimits.outboundRateLimit[dstChainSelector].maxAmountPerPeriod,
            amount
        );

        if (newLastReset != lastReset) {
            rateLimits.outboundRateLimit[dstChainSelector].lastReset = newLastReset;
        }

        if (newUsed != used) {
            rateLimits.outboundRateLimit[dstChainSelector].used = newUsed;
        }
    }

    function _checkInboundRateLimit(uint24 dstChainSelector, uint256 amount) internal {
        s.RateLimits storage rateLimits = s.rateLimits();
        uint32 lastReset = rateLimits.inboundRateLimit[dstChainSelector].lastReset;
        uint128 used = rateLimits.inboundRateLimit[dstChainSelector].used;

        (uint32 newLastReset, uint128 newUsed) = _checkAndConsume(
            rateLimits.inboundRateLimit[dstChainSelector].lastReset,
            rateLimits.inboundRateLimit[dstChainSelector].period,
            rateLimits.inboundRateLimit[dstChainSelector].used,
            rateLimits.inboundRateLimit[dstChainSelector].maxAmountPerPeriod,
            amount
        );

        if (newLastReset != lastReset) {
            rateLimits.inboundRateLimit[dstChainSelector].lastReset = newLastReset;
        }

        if (newUsed != used) {
            rateLimits.inboundRateLimit[dstChainSelector].used = newUsed;
        }
    }

    function _checkAndConsume(
        uint32 lastResetOutbound,
        uint32 period,
        uint128 usedOutbound,
        uint128 maxAmountPerPeriod,
        uint256 requestAmount
    ) internal view returns (uint32 newLastReset, uint128 newUsed) {
        if (period == 0) {
            return (lastResetOutbound, usedOutbound);
        }

        newLastReset = lastResetOutbound;
        newUsed = usedOutbound;

        // Reset if period has passed
        if (block.timestamp >= lastResetOutbound + period) {
            newLastReset = uint32(block.timestamp);
            newUsed = 0;
        }

        // Check limit
        if (newUsed + requestAmount > maxAmountPerPeriod) {
            revert RateLimitExceeded(requestAmount, maxAmountPerPeriod - newUsed);
        }

        newUsed = newUsed + uint128(requestAmount);
    }

    function _getAvailable(
        uint128 maxAmountPerPeriod,
        uint32 period,
        uint32 lastReset,
        uint128 used
    ) internal view returns (uint256 available) {
        // Reset if period has passed
        if (block.timestamp >= lastReset + period) {
            return maxAmountPerPeriod;
        }

        return used >= maxAmountPerPeriod ? 0 : maxAmountPerPeriod - used;
    }
}
