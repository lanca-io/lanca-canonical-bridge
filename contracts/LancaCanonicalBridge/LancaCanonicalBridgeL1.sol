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
import {ReentrancyGuard} from "../common/ReentrancyGuard.sol";

contract LancaCanonicalBridgeL1 is LancaCanonicalBridgeBase, ReentrancyGuard {
    using s for s.L1Bridge;

    uint256 internal constant BRIDGE_GAS_OVERHEAD = 100_000;

    error InvalidLane();
    error PoolNotFound(uint24 dstChainSelector);
    error PoolAlreadyExists(uint24 dstChainSelector);
    error LaneAlreadyExists(uint24 dstChainSelector);

    constructor(
        address conceroRouter,
        address usdcAddress,
        address flowAdmin
    ) LancaCanonicalBridgeBase(usdcAddress, flowAdmin) ConceroClient(conceroRouter) {}

    function sendToken(
        address tokenReceiver,
        uint256 tokenAmount,
        uint24 dstChainSelector,
        bool isContract,
        uint256 dstGasLimit,
        bytes calldata dstCallData
    ) external payable nonReentrant returns (bytes32 messageId) {
        require(tokenAmount > 0, CommonErrors.InvalidAmount());

        s.L1Bridge storage bridge = s.l1Bridge();

        // Get pool and lane
        address pool = bridge.pools[dstChainSelector];
        address lane = bridge.lanes[dstChainSelector];
        require(pool != address(0), PoolNotFound(dstChainSelector));
        require(lane != address(0), InvalidLane()); // TODO: LaneNotFound?

        // Flow limiting check
        _checkOutboundFlow(dstChainSelector, tokenAmount);

        // Process transfer and send message
        if (isContract) {
            messageId = _processTransferToContract(
                tokenReceiver,
                tokenAmount,
                dstChainSelector,
                dstGasLimit,
                dstCallData,
                lane,
                pool
            );
        } else {
            messageId = _processTransferToEOA(
                tokenReceiver,
                tokenAmount,
                dstChainSelector,
                lane,
                pool
            );
        }

        // TODO: fix it
        emit TokenSent(messageId, lane, dstChainSelector, msg.sender, tokenAmount, msg.value);
    }

    function _processTransferToEOA(
        address tokenReceiver,
        uint256 tokenAmount,
        uint24 dstChainSelector,
        address lane,
        address pool
    ) internal returns (bytes32 messageId) {
        ConceroTypes.EvmDstChainData memory dstChainData = ConceroTypes.EvmDstChainData({
            receiver: lane,
            gasLimit: BRIDGE_GAS_OVERHEAD
        });

        // check fee
        uint256 fee = getMessageFee(dstChainSelector, address(0), dstChainData);
        require(msg.value >= fee, InsufficientFee(msg.value, fee));

        // deposit to pool
        require(
            ILancaCanonicalBridgePool(pool).deposit(msg.sender, tokenAmount),
            CommonErrors.TransferFailed()
        );

        // send message
        messageId = IConceroRouter(i_conceroRouter).conceroSend{value: msg.value}(
            dstChainSelector,
            false,
            address(0),
            dstChainData,
			abi.encodePacked(
				abi.encode(tokenReceiver, tokenAmount),
				abi.encodePacked(uint8(0))
			)
        );
    }

    function _processTransferToContract(
        address tokenReceiver,
        uint256 tokenAmount,
        uint24 dstChainSelector,
        uint256 dstGasLimit,
        bytes calldata dstCallData,
        address lane,
		address pool
    ) internal returns (bytes32 messageId) {
        // check fee and deposit in separate scope
        {
            uint256 fee = getMessageFeeForContract(
                dstChainSelector,
                address(0),
                dstGasLimit,
                dstCallData
            );
            require(msg.value >= fee, InsufficientFee(msg.value, fee));

            require(
                ILancaCanonicalBridgePool(pool).deposit(
                    msg.sender,
                    tokenAmount
                ),
                CommonErrors.TransferFailed()
            );
        }

        // send message
        messageId = IConceroRouter(i_conceroRouter).conceroSend{value: msg.value}(
            dstChainSelector,
            false,
            address(0),
            ConceroTypes.EvmDstChainData({
                receiver: lane,
                gasLimit: BRIDGE_GAS_OVERHEAD + dstGasLimit
            }),
			abi.encodePacked(
				abi.encode(tokenReceiver, tokenAmount),
				abi.encodePacked(uint8(1), dstCallData)
			)
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

        _checkInboundFlow(srcChainSelector, amount);

        bool success = ILancaCanonicalBridgePool(pool).withdraw(tokenSender, amount);
        require(success, CommonErrors.TransferFailed());

        emit TokenReceived(
            messageId,
            srcChainSelector,
            address(uint160(uint256(bytes32(sender)))),
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

    function getMessageFeeForContract(
        uint24 dstChainSelector,
        address feeToken,
        uint256 dstGasLimit,
        bytes calldata /** dstCallData */
    ) public view returns (uint256) {
        return
            getMessageFee(
                dstChainSelector,
                feeToken,
                ConceroTypes.EvmDstChainData({
                    receiver: getLane(dstChainSelector),
                    gasLimit: BRIDGE_GAS_OVERHEAD + dstGasLimit
                })
            );
    }

    function getPool(uint24 dstChainSelector) external view returns (address) {
        return s.l1Bridge().pools[dstChainSelector];
    }

    function getLane(uint24 dstChainSelector) public view returns (address) {
        return s.l1Bridge().lanes[dstChainSelector];
    }

    function setOutboundFlowLimit(
        uint24 dstChainSelector,
        uint128 maxAmount,
        uint128 refillSpeed
    ) public onlyFlowAdmin {
        _setFlowLimit(dstChainSelector, maxAmount, refillSpeed, true);
    }

    function setInboundFlowLimit(
        uint24 dstChainSelector,
        uint128 maxAmount,
        uint128 refillSpeed
    ) public onlyFlowAdmin {
        _setFlowLimit(dstChainSelector, maxAmount, refillSpeed, false);
    }
}
