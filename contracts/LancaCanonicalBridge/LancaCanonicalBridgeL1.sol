// SPDX-License-Identifier: MIT
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {LancaCanonicalBridgeBase, ConceroClient, ConceroTypes, IConceroRouter} from "./LancaCanonicalBridgeBase.sol";
import {ILancaCanonicalBridgePool} from "../interfaces/ILancaCanonicalBridgePool.sol";

contract LancaCanonicalBridgeL1 is LancaCanonicalBridgeBase {
    error PoolNotFound(uint24 dstChainSelector);
    error PoolAlreadyExists(uint24 dstChainSelector);

    uint24 private s_migratePoolDstChainSelector;
    address private s_poolImplementation;

    mapping(uint24 dstChainSelector => address pool) public s_pools;

    constructor(
        address conceroRouter,
        uint24 chainSelector,
        address usdcAddress,
        address poolImplementation
    ) LancaCanonicalBridgeBase(chainSelector, usdcAddress) ConceroClient(conceroRouter) {
        s_poolImplementation = poolImplementation;
    }

    function sendToken(
        address dstBridgeAddress,
        uint24 dstChainSelector,
        uint256 amount
    ) private returns (bytes32 messageId) {
        bytes memory message = abi.encode(msg.sender, amount);

        uint256 fee = IConceroRouter(i_conceroRouter).getMessageFee(
            dstChainSelector,
            false,
            address(0),
            ConceroTypes.EvmDstChainData({receiver: dstBridgeAddress, gasLimit: 100_000})
        );

        if (msg.value < fee) {
            revert InsufficientFee(msg.value, fee);
        }

        messageId = IConceroRouter(i_conceroRouter).conceroSend{value: msg.value}(
            dstChainSelector,
            false,
            address(0),
            ConceroTypes.EvmDstChainData({receiver: dstBridgeAddress, gasLimit: 100_000}),
            message
        );

        i_usdc.transferFrom(msg.sender, address(this), amount);

        address pool = s_pools[dstChainSelector];
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

        address pool = s_pools[srcChainSelector];
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

    function createPool(uint24 dstChainSelector) external onlyOwner {
        require(s_pools[dstChainSelector] == address(0), PoolAlreadyExists(dstChainSelector));

        address pool = Clones.clone(s_poolImplementation);
        s_pools[dstChainSelector] = pool;

        ILancaCanonicalBridgePool(pool).initialize(address(i_usdc), dstChainSelector);
    }

    function migratePool(uint24 dstChainSelector) external onlyOwner {
        s_migratePoolDstChainSelector = dstChainSelector;
    }

    function burnLockedUSDC() external onlyOwner {
        address pool = s_pools[s_migratePoolDstChainSelector];
        require(pool != address(0), PoolNotFound(s_migratePoolDstChainSelector));

        delete s_pools[s_migratePoolDstChainSelector];
        s_migratePoolDstChainSelector = 0;

        ILancaCanonicalBridgePool(pool).burnLockedUSDC();
    }
}
