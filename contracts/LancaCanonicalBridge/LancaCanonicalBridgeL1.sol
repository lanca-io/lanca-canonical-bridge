// SPDX-License-Identifier: MIT
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {Storage as s} from "./libraries/Storage.sol";
import {LancaCanonicalBridgeBase, ConceroClient, CommonErrors, ConceroTypes, IConceroRouter} from "./LancaCanonicalBridgeBase.sol";
import {ILancaCanonicalBridgePool} from "../interfaces/ILancaCanonicalBridgePool.sol";

contract LancaCanonicalBridgeL1 is LancaCanonicalBridgeBase {
    using s for s.L1Bridge;

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
        bool shouldFinaliseSrc,
        address /* feeToken */,
        ConceroTypes.EvmDstChainData memory dstChainData
    ) external payable returns (bytes32 messageId) {
        address pool = s.l1Bridge().pools[dstChainSelector];
        address lane = s.l1Bridge().lanes[dstChainSelector];

        require(pool != address(0), PoolNotFound(dstChainSelector));
        require(lane != address(0) && dstChainData.receiver == lane, InvalidLane());

        uint256 fee = getMessageFee(
            dstChainSelector,
            shouldFinaliseSrc,
            address(0),
            dstChainData
        );

        require(msg.value >= fee, InsufficientFee(msg.value, fee));

        bytes memory message = abi.encode(msg.sender, amount);
        messageId = IConceroRouter(i_conceroRouter).conceroSend{value: msg.value}(
            dstChainSelector,
            shouldFinaliseSrc,
            address(0),
            dstChainData,
            message
        );

        bool success = ILancaCanonicalBridgePool(pool).deposit(msg.sender, amount);
        require(success, CommonErrors.TransferFailed());

        emit TokenSent(messageId, lane, dstChainSelector, msg.sender, amount, fee);
    }

    function _conceroReceive(
        bytes32 messageId,
        uint24 srcChainSelector,
        bytes calldata sender,
        bytes calldata message
    ) internal override {
        (address tokenSender, uint256 amount) = abi.decode(message, (address, uint256));

        address pool = s.l1Bridge().pools[srcChainSelector];
        require(pool != address(0), PoolNotFound(srcChainSelector));

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
	
	function getPool(uint24 dstChainSelector) external view returns (address pool) {
		pool = s.l1Bridge().pools[dstChainSelector];
	}
}
