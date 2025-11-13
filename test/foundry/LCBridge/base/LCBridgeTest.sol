// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {LancaCanonicalBridge} from "contracts/LancaCanonicalBridge/LancaCanonicalBridge.sol";
import {LancaCanonicalBridgeClientExample} from "contracts/LancaCanonicalBridgeClient/LancaCanonicalBridgeClientExample.sol";

import {MockUSDCe} from "../../mocks/MockUSDCe.sol";
import {DeployLCBridge} from "../../scripts/deploy/DeployLCBridge.s.sol";
import {BaseTest} from "../../utils/BaseTest.sol";

abstract contract LCBridgeTest is BaseTest {
    LancaCanonicalBridge internal lancaCanonicalBridge;
    LancaCanonicalBridgeClientExample internal lcBridgeClient;

    function setUp() public virtual override {
        super.setUp();

        lancaCanonicalBridge = LancaCanonicalBridge(
            (new DeployLCBridge()).deploy(
                SRC_CHAIN_SELECTOR,
                conceroRouter,
                usdcE,
                lancaBridgeL1Mock,
                deployer
            )
        );
        lcBridgeClient = new LancaCanonicalBridgeClientExample(
            address(lancaCanonicalBridge),
            usdcE
        );

        MockUSDCe(usdcE).setMinter(address(lancaCanonicalBridge));
        MockUSDCe(usdcE).mintTo(user, AMOUNT);

        vm.deal(user, 1e18);

        vm.startPrank(deployer);
        LancaCanonicalBridge(address(lancaCanonicalBridge)).setRateLimit(
            SRC_CHAIN_SELECTOR,
            MAX_RATE_AMOUNT,
            REFILL_SPEED,
            true
        );

        LancaCanonicalBridge(address(lancaCanonicalBridge)).setRateLimit(
            SRC_CHAIN_SELECTOR,
            MAX_RATE_AMOUNT,
            REFILL_SPEED,
            false
        );
        vm.stopPrank();
    }

    function _approveBridge(uint256 amount) internal {
        vm.prank(user);
        MockUSDCe(usdcE).approve(address(lancaCanonicalBridge), amount);
    }

    function _getMessageFee() internal view returns (uint256) {
        return LancaCanonicalBridge(address(lancaCanonicalBridge)).getBridgeNativeFee(ZERO_AMOUNT);
    }

    function _encodeBridgeParams(
        address tokenSender,
        address tokenReceiver,
        uint256 tokenAmount,
        uint256 dstGasLimit,
        bytes memory dstCallData
    ) internal pure returns (bytes memory) {
        return abi.encode(tokenSender, tokenReceiver, tokenAmount, dstGasLimit, dstCallData);
    }

    function _getMessageId(
        uint24 dstChainSelector,
        bool shouldFinaliseSrc,
        address feeToken,
        bytes memory message
    ) internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(block.number, dstChainSelector, shouldFinaliseSrc, feeToken, message)
            );
    }
}
