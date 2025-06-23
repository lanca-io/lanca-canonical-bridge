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

    constructor(
        address conceroRouter,
        uint24 chainSelector,
        address usdcAddress
    ) LancaCanonicalBridgeBase(chainSelector, usdcAddress) ConceroClient(conceroRouter) {}

    function sendToken(
        address dstBridgeAddress,
        uint24 dstChainSelector,
        uint256 amount,
        uint256 gasLimit
    ) private returns (bytes32 messageId) {
        bytes memory message = abi.encode(msg.sender, amount);

        uint256 fee = getMessageFee(
            dstChainSelector,
            false,
            address(0),
            ConceroTypes.EvmDstChainData({receiver: dstBridgeAddress, gasLimit: gasLimit})
        );

        if (msg.value < fee) {
            revert InsufficientFee(msg.value, fee);
        }

        messageId = IConceroRouter(i_conceroRouter).conceroSend{value: msg.value}(
            dstChainSelector,
            false,
            address(0),
            ConceroTypes.EvmDstChainData({receiver: dstBridgeAddress, gasLimit: gasLimit}),
            message
        );

        i_usdc.transferFrom(msg.sender, address(this), amount);

        address pool = s.l1Bridge().pools[dstChainSelector];
        require(pool != address(0), PoolNotFound(dstChainSelector));

        bool success = i_usdc.transfer(pool, amount);
        if (!success) {
            revert TransferFailed();
        }

        emit TokenSent(messageId, dstBridgeAddress, dstChainSelector, msg.sender, amount, fee);
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
        if (!success) {
            revert TransferFailed();
        }

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
}
