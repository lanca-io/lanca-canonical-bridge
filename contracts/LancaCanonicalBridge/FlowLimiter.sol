// SPDX-License-Identifier: MIT
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {CommonErrors} from "@concero/messaging-contracts-v2/contracts/common/CommonErrors.sol";
import {Storage as s} from "./libraries/Storage.sol";

abstract contract FlowLimiter {
    using s for s.FlowLimits;

    error FlowLimitExceeded(uint256 requested, uint256 availableVolume);
    error InvalidFlowConfig(uint128 maxAmount, uint128 refillSpeed);

    event FlowLimitSet(
        uint24 indexed dstChainSelector,
        bool isOutbound,
        uint128 maxAmount,
        uint128 refillSpeed
    );

    struct FlowLimit {
        uint128 availableVolume; // Current available volume for transfers
        uint128 maxAmount; // Maximum allowed flow amount
        uint128 refillSpeed; // Amount added per second (refill rate)
        uint32 lastUpdate; // Last update timestamp for refill calculations
    }

    address public immutable i_flowAdmin;

    modifier onlyFlowAdmin() {
        if (msg.sender != i_flowAdmin) {
            revert CommonErrors.Unauthorized();
        }
        _;
    }

    constructor(address _flowAdmin) {
        i_flowAdmin = _flowAdmin;
    }

    function _setFlowLimit(
        uint24 dstChainSelector,
        uint128 maxAmount,
        uint128 refillSpeed,
        bool isOutbound
    ) internal {
        // Validate: refill speed cannot exceed max amount to prevent overflow
        // Only validate if maxAmount > 0, since 0 means transfers are disabled
        if (maxAmount > 0 && refillSpeed > maxAmount) {
            revert InvalidFlowConfig(maxAmount, refillSpeed);
        }

        s.FlowLimits storage limits = s.flowLimits();
        FlowLimit storage flow = isOutbound
            ? limits.outboundFlows[dstChainSelector]
            : limits.inboundFlows[dstChainSelector];

        // Update available volume based on time elapsed since last update
        if (flow.lastUpdate > 0) {
            (uint128 newAvailable, uint32 newLastUpdate) = _refillFlow(
                flow.availableVolume,
                flow.refillSpeed,
                flow.maxAmount,
                flow.lastUpdate
            );
            flow.availableVolume = newAvailable;
            flow.lastUpdate = newLastUpdate;
        }

        flow.maxAmount = maxAmount;
        flow.refillSpeed = refillSpeed;
        flow.lastUpdate = uint32(block.timestamp);

        // Security: Cap available volume to new max when reducing limits
        // Prevents bypass of new restrictions with previously accumulated amounts
        if (flow.availableVolume > maxAmount) {
            flow.availableVolume = maxAmount;
        }

        // Initialize available volume for first-time setup
        if (flow.availableVolume == 0 && maxAmount > 0) {
            flow.availableVolume = maxAmount;
        }

        emit FlowLimitSet(dstChainSelector, isOutbound, maxAmount, refillSpeed);
    }

    function _checkOutboundFlow(uint24 dstChainSelector, uint256 amount) internal {
        _consumeFlow(dstChainSelector, amount, true);
    }

    function _checkInboundFlow(uint24 dstChainSelector, uint256 amount) internal {
        _consumeFlow(dstChainSelector, amount, false);
    }

    function _consumeFlow(uint24 dstChainSelector, uint256 amount, bool isOutbound) internal {
        if (amount == 0) return;

        s.FlowLimits storage limits = s.flowLimits();
        FlowLimit storage flow = isOutbound
            ? limits.outboundFlows[dstChainSelector]
            : limits.inboundFlows[dstChainSelector];

        uint128 maxAmount = flow.maxAmount;
        uint32 lastUpdate = flow.lastUpdate;

        // If maxAmount = 0, transfers are disabled (soft pause)
        if (maxAmount == 0) {
            revert FlowLimitExceeded(amount, 0);
        }

        // Update available volume with time-based refill
        (uint128 newAvailable, uint32 newLastUpdate) = _refillFlow(
            flow.availableVolume,
            flow.refillSpeed,
            maxAmount,
            lastUpdate
        );

        // Enforce flow limit: revert if requested amount exceeds available
        if (newAvailable < amount) {
            revert FlowLimitExceeded(amount, newAvailable);
        }

        // Consume the requested amount from available flow
        newAvailable -= uint128(amount);

        // Write back only the changed values
        flow.availableVolume = newAvailable;
        if (newLastUpdate != lastUpdate) {
            flow.lastUpdate = newLastUpdate;
        }
    }

    function _refillFlow(
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

    function getOutboundFlowInfo(
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
        FlowLimit memory flow = s.flowLimits().outboundFlows[dstChainSelector];
        return _getCurrentFlowState(flow);
    }

    function getInboundFlowInfo(
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
        FlowLimit memory flow = s.flowLimits().inboundFlows[dstChainSelector];
        return _getCurrentFlowState(flow);
    }

    function _getCurrentFlowState(
        FlowLimit memory flow
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
        // Simulate refill for active flows to show current available volume
        // isActive computed as maxAmount > 0
        bool flowIsActive = flow.maxAmount > 0;
        if (flowIsActive && flow.lastUpdate > 0) {
            uint256 timeElapsed = block.timestamp - flow.lastUpdate;
            uint256 toAdd = timeElapsed * flow.refillSpeed;
            uint256 newAvailable = flow.availableVolume + toAdd;
            // Apply maximum amount capping in simulation
            flow.availableVolume = uint128(
                newAvailable > flow.maxAmount ? flow.maxAmount : newAvailable
            );
        }

        return (
            flow.availableVolume,
            flow.maxAmount,
            flow.refillSpeed,
            flow.lastUpdate,
            flowIsActive
        );
    }
}
