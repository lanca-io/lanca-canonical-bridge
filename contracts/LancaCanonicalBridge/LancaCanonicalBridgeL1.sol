// SPDX-License-Identifier: MIT
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {Storage as s} from "./libraries/Storage.sol";
import {LancaCanonicalBridgeBase, ConceroClient, CommonErrors, ConceroTypes, IConceroRouter, LCBridgeCallData} from "./LancaCanonicalBridgeBase.sol";
import {ILancaCanonicalBridgePool} from "../interfaces/ILancaCanonicalBridgePool.sol";
import {ReentrancyGuard} from "../common/ReentrancyGuard.sol";
import {RateLimiter} from "../common/RateLimiter.sol";

contract LancaCanonicalBridgeL1 is LancaCanonicalBridgeBase, ReentrancyGuard {
    using s for s.L1Bridge;
    using s for s.RateLimits;

    error InvalidLane();
    error PoolNotFound(uint24 dstChainSelector);
    error PoolAlreadyExists(uint24 dstChainSelector);
    error LaneAlreadyExists(uint24 dstChainSelector);

    constructor(
        address conceroRouter,
        address usdcAddress
    ) LancaCanonicalBridgeBase(usdcAddress) ConceroClient(conceroRouter) {}

    function sendToken(
        uint256 amount,
        uint24 dstChainSelector,
        address /* feeToken */,
        ConceroTypes.EvmDstChainData memory dstChainData,
        LCBridgeCallData memory lcbCallData
    ) external payable nonReentrant returns (bytes32 messageId) {
        require(amount > 0, CommonErrors.InvalidAmount());

        s.L1Bridge storage bridge = s.l1Bridge();

        // Get pool and lane
        address pool = bridge.pools[dstChainSelector];
        address lane = bridge.lanes[dstChainSelector];
        require(pool != address(0), PoolNotFound(dstChainSelector));
        require(lane != address(0) && dstChainData.receiver == lane, InvalidLane());

        // Rate limiting check
        _checkOutboundRateLimit(dstChainSelector, amount);

        // Process transfer and send message
        messageId = _processTransfer(amount, dstChainSelector, dstChainData, lcbCallData, pool);

        emit TokenSent(messageId, lane, dstChainSelector, msg.sender, amount, msg.value);
    }

    function _checkOutboundRateLimit(uint24 dstChainSelector, uint256 amount) internal {
        s.RateLimits storage rateLimits = s.rateLimits();

        uint32 lastReset = rateLimits.outboundRateLimit[dstChainSelector].lastReset;
        uint128 used = rateLimits.outboundRateLimit[dstChainSelector].used;

        (uint32 newLastReset, uint128 newUsed) = RateLimiter.checkAndConsume(
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

        (uint32 newLastReset, uint128 newUsed) = RateLimiter.checkAndConsume(
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

    function _processTransfer(
        uint256 amount,
        uint24 dstChainSelector,
        ConceroTypes.EvmDstChainData memory dstChainData,
        LCBridgeCallData memory lcbCallData,
        address pool
    ) internal returns (bytes32 messageId) {
        // check fee
        uint256 fee = getMessageFee(dstChainSelector, address(0), dstChainData);
        require(msg.value >= fee, InsufficientFee(msg.value, fee));

        // deposit to pool
        require(
            ILancaCanonicalBridgePool(pool).deposit(msg.sender, amount),
            CommonErrors.TransferFailed()
        );

        // send message
        messageId = IConceroRouter(i_conceroRouter).conceroSend{value: msg.value}(
            dstChainSelector,
            false,
            address(0),
            dstChainData,
            lcbCallData.tokenReceiver == address(0) // get message
                ? abi.encode(msg.sender, amount) // no receiver, no extra data
                : abi.encode(msg.sender, amount, lcbCallData) // receiver, extra data
        );
    }

    function _conceroReceive(
        bytes32 messageId,
        uint24 srcChainSelector,
        bytes calldata sender,
        bytes calldata message
    ) internal override nonReentrant {
        (address tokenSender, uint256 amount) = abi.decode(message, (address, uint256));

        address pool = s.l1Bridge().pools[srcChainSelector];
        require(pool != address(0), PoolNotFound(srcChainSelector));

        _checkInboundRateLimit(srcChainSelector, amount);

        bool success = ILancaCanonicalBridgePool(pool).withdraw(tokenSender, amount);
        require(success, CommonErrors.TransferFailed());

        emit TokenReceived(
            messageId,
            srcChainSelector,
            address(bytes20(sender)),
            tokenSender,
            amount
        );
    }

    function setOutboundRateLimit(
        uint24 dstChainSelector,
        uint32 period,
        uint128 maxAmountPerPeriod
    ) external onlyOwner {
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
    ) external onlyOwner {
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
        external
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

        availableAmount = RateLimiter.getAvailable(
            maxAmountPerPeriod,
            period,
            lastReset,
            usedAmount
        );
    }

    function getInboundRateLimitInfo(
        uint24 dstChainSelector
    )
        external
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

        availableAmount = RateLimiter.getAvailable(
            maxAmountPerPeriod,
            period,
            lastReset,
            usedAmount
        );
    }

    function addPools(
        uint24[] calldata dstChainSelectors,
        address[] calldata pools
    ) external onlyOwner {
        require(dstChainSelectors.length == pools.length, CommonErrors.LengthMismatch());

        s.L1Bridge storage l1BridgeStorage = s.l1Bridge();

        for (uint256 i = 0; i < dstChainSelectors.length; i++) {
            require(
                l1BridgeStorage.pools[dstChainSelectors[i]] == address(0),
                PoolAlreadyExists(dstChainSelectors[i])
            );
            l1BridgeStorage.pools[dstChainSelectors[i]] = pools[i];
        }
    }

    function addLanes(
        uint24[] calldata dstChainSelectors,
        address[] calldata lanes
    ) external onlyOwner {
        require(dstChainSelectors.length == lanes.length, CommonErrors.LengthMismatch());

        s.L1Bridge storage l1BridgeStorage = s.l1Bridge();

        for (uint256 i = 0; i < dstChainSelectors.length; i++) {
            require(
                l1BridgeStorage.lanes[dstChainSelectors[i]] == address(0),
                LaneAlreadyExists(dstChainSelectors[i])
            );
            l1BridgeStorage.lanes[dstChainSelectors[i]] = lanes[i];
        }
    }

    function getPool(uint24 dstChainSelector) external view returns (address) {
        return s.l1Bridge().pools[dstChainSelector];
    }

    function getLane(uint24 dstChainSelector) external view returns (address) {
        return s.l1Bridge().lanes[dstChainSelector];
    }
}
