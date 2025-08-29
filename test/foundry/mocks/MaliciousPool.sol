// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {LancaCanonicalBridgeL1} from "contracts/LancaCanonicalBridge/LancaCanonicalBridgeL1.sol";
import {ILancaCanonicalBridgePool} from "contracts/interfaces/ILancaCanonicalBridgePool.sol";

contract MaliciousPool is ILancaCanonicalBridgePool {
    address public target;
    bool public shouldAttack;

    function setTarget(address _target) external {
        target = _target;
    }

    function deposit(address /* from */, uint256 amount) external {
        if (shouldAttack) {
            shouldAttack = false;

            LancaCanonicalBridgeL1(target).sendToken(
                address(0),
                amount,
                8453, // DST_CHAIN_SELECTOR
                0,
                ""
            );
        }
    }

    function withdraw(address /* to */, uint256 /* amount */) external {}

    function getPoolInfo() external pure returns (uint24, uint256) {
        return (8453, 0);
    }

    function setAttackMode(bool _shouldAttack) external {
        shouldAttack = _shouldAttack;
    }
}
