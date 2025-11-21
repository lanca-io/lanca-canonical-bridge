// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {MessageCodec} from "@concero/v2-contracts/contracts/common/libraries/MessageCodec.sol";

import {LancaCanonicalBridge} from "contracts/LancaCanonicalBridge/LancaCanonicalBridge.sol";

import {MockUSDCe} from "./MockUSDCe.sol";

contract MaliciousToken is MockUSDCe {
    bool public shouldAttack;
    address public attackTarget;

    constructor() MockUSDCe("Malicious USDC", "mUSDC", 6) {}

    function setAttackMode(bool _shouldAttack, address _target) external {
        shouldAttack = _shouldAttack;
        attackTarget = _target;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        if (shouldAttack) {
            shouldAttack = false;

            bytes memory dstChainData = MessageCodec.encodeEvmDstChainData(address(this), 0);

            LancaCanonicalBridge(attackTarget).sendToken(amount, dstChainData, "");
        }

        return super.transferFrom(from, to, amount);
    }
}
