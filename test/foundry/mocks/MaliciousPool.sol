// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ConceroTypes} from "@concero/messaging-contracts-v2/contracts/ConceroClient/ConceroTypes.sol";

import {LCBridgeCallData} from "contracts/LancaCanonicalBridge/LancaCanonicalBridgeBase.sol";
import {LancaCanonicalBridgeL1} from "contracts/LancaCanonicalBridge/LancaCanonicalBridgeL1.sol";
import {ILancaCanonicalBridgePool} from "contracts/interfaces/ILancaCanonicalBridgePool.sol";

contract MaliciousPool is ILancaCanonicalBridgePool {
    address public immutable usdc;
    LancaCanonicalBridgeL1 public immutable bridge;
    uint24 public immutable dstChainSelector;
    address public immutable dstLcbBridge;
    bool public shouldAttack;

    constructor(address _usdc, address _bridge, uint24 _dstChainSelector, address _dstLcbBridge) {
        usdc = _usdc;
        bridge = LancaCanonicalBridgeL1(_bridge);
        dstChainSelector = _dstChainSelector;
        dstLcbBridge = _dstLcbBridge;
    }

    function deposit(address from, uint256 amount) external returns (bool) {
        bool success = IERC20(usdc).transferFrom(from, address(this), amount);

        if (shouldAttack) {
            shouldAttack = false;

            uint256 messageFee = bridge.getMessageFee(
                dstChainSelector,
                address(0),
                ConceroTypes.EvmDstChainData({receiver: dstLcbBridge, gasLimit: 500000})
            );

            bridge.sendToken{value: messageFee}(
                amount,
                dstChainSelector,
                address(0),
                ConceroTypes.EvmDstChainData({receiver: dstLcbBridge, gasLimit: 500000}),
				LCBridgeCallData({
					tokenReceiver: address(0),
					receiverData: ""
				})
            );
        }

        return success;
    }

    function withdraw(address to, uint256 amount) external returns (bool) {
        return IERC20(usdc).transfer(to, amount);
    }

    function getPoolInfo() external view returns (uint24, uint256) {
        return (dstChainSelector, IERC20(usdc).balanceOf(address(this)));
    }

    function setAttackMode(bool _shouldAttack) external {
        shouldAttack = _shouldAttack;
    }
}
