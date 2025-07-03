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

    error FlowLimitExceeded(uint256 requested, uint256 available);
    error InvalidFlowConfig(uint128 maxAmount, uint128 refillSpeed);

    event FlowLimitSet(
        uint24 indexed dstChainSelector,
        bool isOutbound,
        uint128 maxAmount,
        uint128 refillSpeed
    );

    struct FlowLimit {
        uint128 available;
        uint128 maxAmount;
        uint128 refillSpeed;
        uint32 lastUpdate;
        bool isActive;
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
        if (maxAmount > 0 && refillSpeed > maxAmount) {
            revert InvalidFlowConfig(maxAmount, refillSpeed);
        }

        s.FlowLimits storage limits = s.flowLimits();
        FlowLimit storage flow = isOutbound
            ? limits.outboundFlows[dstChainSelector]
            : limits.inboundFlows[dstChainSelector];

        if (flow.lastUpdate > 0) {
            _refillFlow(flow);
        }

        flow.maxAmount = maxAmount;
        flow.refillSpeed = refillSpeed;
        flow.isActive = maxAmount > 0;
        flow.lastUpdate = uint32(block.timestamp);

        if (flow.available > maxAmount) {
            flow.available = maxAmount;
        }

        if (flow.available == 0 && maxAmount > 0) {
            flow.available = maxAmount;
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

        if (!flow.isActive) return;

        _refillFlow(flow);

        if (flow.available < amount) {
            revert FlowLimitExceeded(amount, flow.available);
        }

        flow.available -= uint128(amount);
    }

    function _refillFlow(FlowLimit storage flow) internal {
        uint256 timeElapsed = block.timestamp - flow.lastUpdate;
        if (timeElapsed == 0) return;

        uint256 toAdd = timeElapsed * flow.refillSpeed;
        uint256 newAvailable = flow.available + toAdd;

        flow.available = uint128(newAvailable > flow.maxAmount ? flow.maxAmount : newAvailable);
        flow.lastUpdate = uint32(block.timestamp);
    }

    function getOutboundFlowInfo(
        uint24 dstChainSelector
    )
        public
        view
        returns (
            uint128 available,
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
            uint128 available,
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
            uint128 available,
            uint128 maxAmount,
            uint128 refillSpeed,
            uint32 lastUpdate,
            bool isActive
        )
    {
        if (flow.isActive && flow.lastUpdate > 0) {
            uint256 timeElapsed = block.timestamp - flow.lastUpdate;
            uint256 toAdd = timeElapsed * flow.refillSpeed;
            uint256 newAvailable = flow.available + toAdd;
            flow.available = uint128(newAvailable > flow.maxAmount ? flow.maxAmount : newAvailable);
        }

        return (flow.available, flow.maxAmount, flow.refillSpeed, flow.lastUpdate, flow.isActive);
    }
}
