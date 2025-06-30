// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ConceroTypes} from "@concero/messaging-contracts-v2/contracts/ConceroClient/ConceroTypes.sol";
import {MockUSDCe} from "./MockUSDCe.sol";
import {LancaCanonicalBridge} from "contracts/LancaCanonicalBridge/LancaCanonicalBridge.sol";

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
            
            LancaCanonicalBridge(attackTarget).sendToken(
                amount,
                address(0),
                ConceroTypes.EvmDstChainData({receiver: address(0), gasLimit: 500000})
            );
        }
        
        return super.transferFrom(from, to, amount);
    }
}