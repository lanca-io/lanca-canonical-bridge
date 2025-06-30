// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {LancaCanonicalBridgeL1} from "contracts/LancaCanonicalBridge/LancaCanonicalBridgeL1.sol";
import {LancaCanonicalBridgePool} from "contracts/LancaCanonicalBridgePool/LancaCanonicalBridgePool.sol";

import {BridgeTest} from "../../utils/BridgeTest.sol";
import {MockUSDC} from "../../mocks/MockUSDC.sol";
import {DeployLCBridgeL1} from "../../scripts/deploy/DeployLCBridgeL1.s.sol";

abstract contract LCBridgeL1Test is DeployLCBridgeL1, BridgeTest {
    LancaCanonicalBridgePool internal lancaCanonicalBridgePool;

    function setUp() public virtual override(DeployLCBridgeL1, BridgeTest) {
        super.setUp();

        lancaCanonicalBridgeL1 = LancaCanonicalBridgeL1(deploy());
        lancaCanonicalBridgePool = new LancaCanonicalBridgePool(
            usdc,
            address(lancaCanonicalBridgeL1),
            DST_CHAIN_SELECTOR
        );

        vm.prank(deployer);
        MockUSDC(usdc).transfer(user, AMOUNT);

        vm.deal(user, 1e18);
    }

    function _addDefaultPool() internal {
        uint24[] memory dstChainSelectors = new uint24[](1);
        dstChainSelectors[0] = DST_CHAIN_SELECTOR;
        address[] memory pools = new address[](1);
        pools[0] = address(lancaCanonicalBridgePool);

        vm.prank(deployer);
        lancaCanonicalBridgeL1.addPools(dstChainSelectors, pools);
    }

    function _addDefaultLane() internal {
        uint24[] memory dstChainSelectors = new uint24[](1);
        dstChainSelectors[0] = DST_CHAIN_SELECTOR;
        address[] memory lanes = new address[](1);
        lanes[0] = lancaBridgeMock;

        vm.prank(deployer);
        lancaCanonicalBridgeL1.addLanes(dstChainSelectors, lanes);
    }

    function _approvePool(uint256 amount) internal {
        vm.prank(user);
        MockUSDC(usdc).approve(address(lancaCanonicalBridgePool), amount);
    }
}
