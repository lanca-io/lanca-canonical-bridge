// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {LCBTransparentUpgradeableProxy} from "../../../contracts/Proxy/LCBTransparentUpgradeableProxy.sol";
import {BridgeCodec} from "contracts/common/libraries/BridgeCodec.sol";
import {IConceroRouter} from "@concero/v2-contracts/contracts/interfaces/IConceroRouter.sol";
import {LCBTest} from "../helpers/LCBTest.sol";
import {LancaCanonicalBridgeClientExample} from "contracts/LancaCanonicalBridgeClient/LancaCanonicalBridgeClientExample.sol";
import {LancaCanonicalBridgeL1} from "contracts/LancaCanonicalBridge/LancaCanonicalBridgeL1.sol";
import {LancaCanonicalBridgeBase} from "contracts/LancaCanonicalBridge/LancaCanonicalBridgeBase.sol";
import {LancaCanonicalBridgePool} from "contracts/LancaCanonicalBridgePool/LancaCanonicalBridgePool.sol";
import {MessageCodec} from "@concero/v2-contracts/contracts/common/libraries/MessageCodec.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";

abstract contract LCBridgeL1Base is LCBTest {
    using MessageCodec for IConceroRouter.MessageRequest;

    LancaCanonicalBridgeL1 internal lancaCanonicalBridgeL1;
    LancaCanonicalBridgePool internal lancaCanonicalBridgePool;
    LancaCanonicalBridgeClientExample internal lcBridgeClient;

    function setUp() public virtual {
        lancaCanonicalBridgeL1 = LancaCanonicalBridgeL1(
            address(
                new LCBTransparentUpgradeableProxy(
                    address(new LancaCanonicalBridgeL1(s_conceroRouter, address(s_usdc))),
                    s_proxyDeployer,
                    abi.encodeWithSelector(LancaCanonicalBridgeBase.initialize.selector, s_deployer)
                )
            )
        );

        uint24[] memory dstChainSelectors = new uint24[](1);
        dstChainSelectors[0] = SRC_CHAIN_SELECTOR;

        _setValidatorLibs(address(lancaCanonicalBridgeL1));
        _setRelayerLib(address(lancaCanonicalBridgeL1));

        lancaCanonicalBridgePool = new LancaCanonicalBridgePool(
            address(s_usdc),
            address(lancaCanonicalBridgeL1),
            DST_CHAIN_SELECTOR
        );

        lcBridgeClient = new LancaCanonicalBridgeClientExample(
            address(lancaCanonicalBridgeL1),
            address(s_usdc)
        );

        deal(address(s_usdc), s_user, AMOUNT);
        vm.deal(s_user, 1e18);

        vm.startPrank(s_deployer);
        lancaCanonicalBridgeL1.grantRole(lancaCanonicalBridgeL1.RATE_LIMIT_ADMIN(), s_deployer);

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

        vm.prank(s_deployer);
        lancaCanonicalBridgeL1.addPools(dstChainSelectors, pools);
    }

    function _addDefaultDstBridge() internal {
        uint24[] memory dstChainSelectors = new uint24[](1);
        dstChainSelectors[0] = DST_CHAIN_SELECTOR;
        bytes32[] memory dstBridges = new bytes32[](1);
        dstBridges[0] = BridgeCodec.toBytes32(s_lancaBridgeMock);

        vm.prank(s_deployer);
        lancaCanonicalBridgeL1.addDstBridges(dstChainSelectors, dstBridges);
    }

    function _approvePool(uint256 amount) internal {
        vm.prank(s_user);
        s_usdc.approve(address(lancaCanonicalBridgePool), amount);
    }

    function _getMessageFee() internal view returns (uint256) {
        return
            lancaCanonicalBridgeL1.getBridgeNativeFee(
                ZERO_AMOUNT,
                DST_CHAIN_SELECTOR,
                MessageCodec.encodeEvmDstChainData(address(lancaCanonicalBridgeL1), 0),
                ZERO_BYTES
            );
    }

    function _conceroReceive(
        address tokenSender,
        address tokenReceiver,
        uint256 tokenAmount,
        uint32 dstGasLimit,
        bytes memory payload
    ) internal {
        IConceroRouter.MessageRequest memory messageRequest = _buildMessageRequest(
            BridgeCodec.encodeBridgeData(tokenSender, tokenReceiver, tokenAmount, payload),
            SRC_CHAIN_SELECTOR,
            address(lancaCanonicalBridgeL1),
            dstGasLimit
        );

        vm.prank(s_conceroRouter);
        lancaCanonicalBridgeL1.conceroReceive(
            messageRequest.toMessageReceiptBytes(
                DST_CHAIN_SELECTOR,
                s_lancaBridgeMock,
                NONCE,
                new bytes[](0)
            ),
            s_validationChecks,
            s_validatorLibs,
            s_relayerLib
        );
    }
}
