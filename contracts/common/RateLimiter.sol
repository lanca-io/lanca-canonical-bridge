// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library RateLimiter {
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

    function checkAndConsume(
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

    function getAvailable(
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
