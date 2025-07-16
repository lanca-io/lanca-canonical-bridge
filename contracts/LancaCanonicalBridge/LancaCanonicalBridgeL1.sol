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

    error InvalidDstBridge();
    error PoolNotFound(uint24 dstChainSelector);
    error PoolAlreadyExists(uint24 dstChainSelector);
    error DstBridgeAlreadyExists(uint24 dstChainSelector);

    constructor(
        address conceroRouter,
        address usdcAddress,
        address rateAdmin
    ) LancaCanonicalBridgeBase(usdcAddress, rateAdmin) ConceroClient(conceroRouter) {}

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

        // Get pool and dstBridge
        address pool = bridge.pools[dstChainSelector];
        address dstBridge = bridge.dstBridges[dstChainSelector];
        require(pool != address(0), PoolNotFound(dstChainSelector));
        require(dstBridge != address(0), InvalidDstBridge());

        _consumeRate(dstChainSelector, tokenAmount, true);

        messageId = _processTransfer(
            tokenReceiver,
            tokenAmount,
            dstChainSelector,
            isContract,
            dstGasLimit,
            dstCallData,
            dstBridge,
            pool
        );

        emit TokenSent(
            messageId,
            dstBridge,
            dstChainSelector,
            msg.sender,
            tokenReceiver,
            tokenAmount,
            msg.value
        );
    }

    function _processTransfer(
        address tokenReceiver,
        uint256 tokenAmount,
        uint24 dstChainSelector,
        bool isContract,
        uint256 dstGasLimit,
        bytes calldata dstCallData,
        address dstBridge,
        address pool
    ) internal returns (bytes32 messageId) {
        ConceroTypes.EvmDstChainData memory dstChainData = ConceroTypes.EvmDstChainData({
            receiver: dstBridge,
            gasLimit: isContract ? BRIDGE_GAS_OVERHEAD + dstGasLimit : BRIDGE_GAS_OVERHEAD
        });

        // check fee
        uint256 fee = getMessageFee(dstChainSelector, address(0), dstChainData);
        require(msg.value >= fee, InsufficientFee(msg.value, fee));

        // deposit to pool
        require(
            ILancaCanonicalBridgePool(pool).deposit(msg.sender, tokenAmount),
            CommonErrors.TransferFailed()
        );

        bytes memory message = abi.encodePacked(
            abi.encode(msg.sender, tokenReceiver, tokenAmount),
            isContract ? abi.encodePacked(uint8(1), dstCallData) : abi.encodePacked(uint8(0))
        );

        // send message
        messageId = IConceroRouter(i_conceroRouter).conceroSend{value: msg.value}(
            dstChainSelector,
            false,
            address(0),
            dstChainData,
            message
        );
    }

    function _conceroReceive(
        bytes32 messageId,
        uint24 srcChainSelector,
        bytes calldata sender,
        bytes calldata message
    ) internal override nonReentrant {
        address srcBridge = getBridgeAddress(srcChainSelector);
        address messageSender = abi.decode(sender, (address));
        require(messageSender == srcBridge, InvalidSenderBridge());

        (address tokenSender, address tokenReceiver, uint256 tokenAmount) = abi.decode(
            message,
            (address, address, uint256)
        );

        address pool = s.l1Bridge().pools[srcChainSelector];
        require(pool != address(0), PoolNotFound(srcChainSelector));

        _consumeRate(srcChainSelector, tokenAmount, false);

        bool success = ILancaCanonicalBridgePool(pool).withdraw(tokenReceiver, tokenAmount);
        require(success, CommonErrors.TransferFailed());

        emit TokenReceived(
            messageId,
            srcBridge,
            srcChainSelector,
            tokenSender,
            tokenReceiver,
            tokenAmount
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

    function addDstBridges(
        uint24[] calldata dstChainSelectors,
        address[] calldata dstBridges
    ) external onlyOwner {
        require(dstChainSelectors.length == dstBridges.length, CommonErrors.LengthMismatch());

        s.L1Bridge storage l1BridgeStorage = s.l1Bridge();

        for (uint256 i = 0; i < dstChainSelectors.length; i++) {
            require(
                l1BridgeStorage.dstBridges[dstChainSelectors[i]] == address(0),
                DstBridgeAlreadyExists(dstChainSelectors[i])
            );
            l1BridgeStorage.dstBridges[dstChainSelectors[i]] = dstBridges[i];
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
                    receiver: getBridgeAddress(dstChainSelector),
                    gasLimit: BRIDGE_GAS_OVERHEAD + dstGasLimit
                })
            );
    }

    function getPool(uint24 dstChainSelector) external view returns (address) {
        return s.l1Bridge().pools[dstChainSelector];
    }

    function getBridgeAddress(uint24 dstChainSelector) public view returns (address) {
        return s.l1Bridge().dstBridges[dstChainSelector];
    }

    function setRateLimit(
        uint24 dstChainSelector,
        uint128 maxAmount,
        uint128 refillSpeed,
        bool isOutbound
    ) public onlyRateLimitAdmin {
        _setRateLimit(dstChainSelector, maxAmount, refillSpeed, isOutbound);
    }
}
