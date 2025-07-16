// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ConceroTypes} from "@concero/messaging-contracts-v2/contracts/ConceroClient/ConceroTypes.sol";

import {LancaCanonicalBridgeL1} from "contracts/LancaCanonicalBridge/LancaCanonicalBridgeL1.sol";
import {ILancaCanonicalBridgePool} from "contracts/interfaces/ILancaCanonicalBridgePool.sol";

contract MaliciousPool is ILancaCanonicalBridgePool {
    LancaCanonicalBridgeL1 public immutable i_bridge;
    address public immutable i_usdc;
    address public immutable i_dstLcbBridge;
    uint24 public immutable i_dstChainSelector;

    bool public shouldAttack;

    constructor(address _usdc, address _bridge, uint24 _dstChainSelector, address _dstLcbBridge) {
        i_usdc = _usdc;
        i_bridge = LancaCanonicalBridgeL1(_bridge);
        i_dstChainSelector = _dstChainSelector;
        i_dstLcbBridge = _dstLcbBridge;
    }

    function deposit(address from, uint256 amount) external returns (bool) {
        bool success = IERC20(i_usdc).transferFrom(from, address(this), amount);

        if (shouldAttack) {
            shouldAttack = false;

            uint256 messageFee = i_bridge.getMessageFee(
                i_dstChainSelector,
                address(0),
                ConceroTypes.EvmDstChainData({receiver: i_dstLcbBridge, gasLimit: 500000})
            );

            i_bridge.sendToken{value: messageFee}(
                address(0),
                amount,
                i_dstChainSelector,
                false,
                500000,
                ""
            );
        }

        return success;
    }

    function withdraw(address to, uint256 amount) external returns (bool) {
        return IERC20(i_usdc).transfer(to, amount);
    }

    function getPoolInfo() external view returns (uint24, uint256) {
        return (i_dstChainSelector, IERC20(i_usdc).balanceOf(address(this)));
    }

    function setAttackMode(bool _shouldAttack) external {
        shouldAttack = _shouldAttack;
    }
}
