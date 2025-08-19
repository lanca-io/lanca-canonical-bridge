// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {LancaCanonicalBridgeL1} from "contracts/LancaCanonicalBridge/LancaCanonicalBridgeL1.sol";
import {LancaCanonicalBridgePool} from "contracts/LancaCanonicalBridgePool/LancaCanonicalBridgePool.sol";
import {LancaCanonicalBridgeClientExample} from "contracts/LancaCanonicalBridgeClient/LancaCanonicalBridgeClientExample.sol";

import {BridgeTest} from "../../utils/BridgeTest.sol";
import {MockUSDC} from "../../mocks/MockUSDC.sol";
import {DeployLCBridgeL1} from "../../scripts/deploy/DeployLCBridgeL1.s.sol";

abstract contract LCBridgeL1Test is DeployLCBridgeL1, BridgeTest {
    LancaCanonicalBridgePool internal lancaCanonicalBridgePool;
    LancaCanonicalBridgeClientExample internal lcBridgeClient;

    function setUp() public virtual override(DeployLCBridgeL1, BridgeTest) {
        super.setUp();

        lancaCanonicalBridgeL1 = LancaCanonicalBridgeL1(deploy());
        lancaCanonicalBridgePool = new LancaCanonicalBridgePool(
            usdc,
            address(lancaCanonicalBridgeL1),
            DST_CHAIN_SELECTOR
        );

        lcBridgeClient = new LancaCanonicalBridgeClientExample(address(lancaCanonicalBridgeL1), usdc);

        deal(address(usdc), user, AMOUNT);
        vm.deal(user, 1e18);

        vm.startPrank(deployer);
        lancaCanonicalBridgeL1.setRateLimit(
            DST_CHAIN_SELECTOR,
            MAX_RATE_AMOUNT,
            REFILL_SPEED,
            true
        );

        lancaCanonicalBridgeL1.setRateLimit(
            DST_CHAIN_SELECTOR,
            MAX_RATE_AMOUNT,
            REFILL_SPEED,
            false
        );
        vm.stopPrank();
    }

    function _addDefaultPool() internal {
        uint24[] memory dstChainSelectors = new uint24[](1);
        dstChainSelectors[0] = DST_CHAIN_SELECTOR;
        address[] memory pools = new address[](1);
        pools[0] = address(lancaCanonicalBridgePool);

        vm.prank(deployer);
        lancaCanonicalBridgeL1.addPools(dstChainSelectors, pools);
    }

    function _addDefaultDstBridge() internal {
        uint24[] memory dstChainSelectors = new uint24[](1);
        dstChainSelectors[0] = DST_CHAIN_SELECTOR;
        address[] memory dstBridges = new address[](1);
        dstBridges[0] = lancaBridgeMock;

        vm.prank(deployer);
        lancaCanonicalBridgeL1.addDstBridges(dstChainSelectors, dstBridges);
    }

    function _approvePool(uint256 amount) internal {
        vm.prank(user);
        MockUSDC(usdc).approve(address(lancaCanonicalBridgePool), amount);
    }

    function _getMessageFee() internal view returns (uint256) {
        return
            lancaCanonicalBridgeL1.getBridgeNativeFee(
                DST_CHAIN_SELECTOR,
                address(lancaBridgeMock),
                ZERO_AMOUNT
            );
    }
}
