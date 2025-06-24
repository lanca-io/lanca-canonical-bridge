// SPDX-License-Identifier: MIT
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {Storage as s} from "./libraries/Storage.sol";
import {LancaCanonicalBridgeBase, ConceroClient, CommonErrors, ConceroTypes, IConceroRouter} from "./LancaCanonicalBridgeBase.sol";

contract LancaCanonicalBridge is LancaCanonicalBridgeBase {
    using s for s.Bridge;

    error LaneNotFound(uint24 dstChainSelector);
    error LaneAlreadyExists(uint24 dstChainSelector);

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
    ) external payable returns (bytes32 messageId) {
        address lane = s.bridge().lanes[dstChainSelector];
        require(lane != address(0), LaneNotFound(dstChainSelector));

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

        bool success = i_usdc.transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert TransferFailed();
        }
        i_usdc.burn(amount);

        emit TokenSent(messageId, dstBridgeAddress, dstChainSelector, msg.sender, amount, fee);
    }

    function _conceroReceive(
        bytes32 messageId,
        uint24 srcChainSelector,
        bytes calldata sender,
        bytes calldata message
    ) internal override {
        (address tokenSender, uint256 amount) = abi.decode(message, (address, uint256));

        bool success = i_usdc.mint(tokenSender, amount);
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

    function addLanes(
        uint24[] calldata dstChainSelectors,
        address[] calldata lanes
    ) external onlyOwner {
        require(dstChainSelectors.length == lanes.length, CommonErrors.LengthMismatch());

        s.Bridge storage bridgeStorage = s.bridge();

        for (uint256 i = 0; i < dstChainSelectors.length; i++) {
            require(bridgeStorage.lanes[dstChainSelectors[i]] == address(0), LaneAlreadyExists(dstChainSelectors[i]));
            bridgeStorage.lanes[dstChainSelectors[i]] = lanes[i];
        }
    }
}
