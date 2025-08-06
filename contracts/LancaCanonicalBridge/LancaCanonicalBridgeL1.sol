// SPDX-License-Identifier: MIT
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {CommonErrors} from "@concero/v2-contracts/contracts/common/CommonErrors.sol";

import {LancaCanonicalBridgeBase, ILancaCanonicalBridgeClient, ConceroClient} from "./LancaCanonicalBridgeBase.sol";
import {Storage as s} from "./libraries/Storage.sol";
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
        address rateLimitAdmin
    ) LancaCanonicalBridgeBase(usdcAddress, rateLimitAdmin) ConceroClient(conceroRouter) {}

    /* ------- Main Functions ------- */

    function sendToken(
        address tokenReceiver,
        uint256 tokenAmount,
        uint24 dstChainSelector,
        uint256 dstGasLimit,
        bytes calldata dstCallData
    ) external payable nonReentrant returns (bytes32 messageId) {
        require(tokenAmount > 0, CommonErrors.InvalidAmount());

        s.L1Bridge storage bridge = s.l1Bridge();

        address pool = bridge.pools[dstChainSelector];
        address dstBridge = bridge.dstBridges[dstChainSelector];
        require(pool != address(0), PoolNotFound(dstChainSelector));
        require(dstBridge != address(0), InvalidDstBridge());

        _consumeRate(dstChainSelector, tokenAmount, true);
        _depositToPool(msg.sender, tokenAmount, pool);

        messageId = _sendMessage(
            tokenReceiver,
            tokenAmount,
            dstChainSelector,
            dstGasLimit,
            dstCallData,
            dstBridge
        );

        emit TokenSent(messageId, msg.sender, tokenReceiver, tokenAmount);
        emit SentToDestinationBridge(messageId, dstChainSelector, dstBridge);
    }

    function _conceroReceive(
        bytes32 messageId,
        uint24 srcChainSelector,
        bytes calldata sender,
        bytes calldata message
    ) internal override nonReentrant {
        address srcBridge = getBridgeAddress(srcChainSelector);
        address messageSender = abi.decode(sender, (address));
        require(messageSender == srcBridge, InvalidBridgeSender());

        address pool = s.l1Bridge().pools[srcChainSelector];
        require(pool != address(0), PoolNotFound(srcChainSelector));

        (
            address tokenSender,
            address tokenReceiver,
            uint256 tokenAmount,
            uint256 dstGasLimit,
            bytes memory dstCallData
        ) = _decodeMessage(message);

        _consumeRate(srcChainSelector, tokenAmount, false);

        if (dstGasLimit == 0 && dstCallData.length == 0) {
            _withdrawFromPool(pool, tokenReceiver, tokenAmount);
        } else if (_isValidContractReceiver(tokenReceiver)) {
            _withdrawFromPool(pool, tokenReceiver, tokenAmount);

            ILancaCanonicalBridgeClient(tokenReceiver).lancaCanonicalBridgeReceive{
                gas: dstGasLimit
            }(address(i_usdc), tokenSender, tokenAmount, dstCallData);
        }

        emit BridgeDelivered(
            messageId,
            srcBridge,
            srcChainSelector,
            tokenSender,
            tokenReceiver,
            tokenAmount
        );
    }

    /* ------- Private Functions ------- */

    function _depositToPool(address tokenSender, uint256 tokenAmount, address pool) private {
        ILancaCanonicalBridgePool(pool).deposit(tokenSender, tokenAmount);
    }

    function _withdrawFromPool(address pool, address tokenReceiver, uint256 tokenAmount) private {
        ILancaCanonicalBridgePool(pool).withdraw(tokenReceiver, tokenAmount);
    }

    /* ------- Admin Functions ------- */

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

    function removePools(uint24[] calldata dstChainSelectors) external onlyOwner {
        s.L1Bridge storage l1BridgeStorage = s.l1Bridge();
        for (uint256 i = 0; i < dstChainSelectors.length; i++) {
            delete l1BridgeStorage.pools[dstChainSelectors[i]];
        }
    }

    function removeDstBridges(uint24[] calldata dstChainSelectors) external onlyOwner {
        s.L1Bridge storage l1BridgeStorage = s.l1Bridge();
        for (uint256 i = 0; i < dstChainSelectors.length; i++) {
            delete l1BridgeStorage.dstBridges[dstChainSelectors[i]];
        }
    }

    /* ------- View Functions ------- */

    function getMessageFeeForContract(
        uint24 dstChainSelector,
        address feeToken,
        uint256 dstGasLimit,
        bytes calldata dstCallData
    ) public view returns (uint256) {
        return
            _getMessageFeeForContract(
                dstChainSelector,
                getBridgeAddress(dstChainSelector),
                feeToken,
                dstGasLimit,
                dstCallData
            );
    }

    function getPool(uint24 dstChainSelector) external view returns (address) {
        return s.l1Bridge().pools[dstChainSelector];
    }

    function getBridgeAddress(uint24 dstChainSelector) public view returns (address) {
        return s.l1Bridge().dstBridges[dstChainSelector];
    }
}
