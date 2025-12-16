// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {IConceroRouter} from "@concero/v2-contracts/contracts/interfaces/IConceroRouter.sol";
import {MessageCodec} from "@concero/v2-contracts/contracts/common/libraries/MessageCodec.sol";

import {LancaCanonicalBridge} from "contracts/LancaCanonicalBridge/LancaCanonicalBridge.sol";
import {LancaCanonicalBridgeBase} from "contracts/LancaCanonicalBridge/LancaCanonicalBridgeBase.sol";
import {LancaCanonicalBridgeClientExample} from "contracts/LancaCanonicalBridgeClient/LancaCanonicalBridgeClientExample.sol";
import {BridgeCodec} from "contracts/common/libraries/BridgeCodec.sol";

import {MockUSDCe} from "../mocks/MockUSDCe.sol";
import {LCBTest} from "../helpers/LCBTest.sol";
import {TransparentUpgradeableProxy} from "../../../contracts/Proxy/TransparentUpgradeableProxy.sol";

abstract contract LCBridgeBase is LCBTest {
    using MessageCodec for IConceroRouter.MessageRequest;

    LancaCanonicalBridge internal lancaCanonicalBridge;
    LancaCanonicalBridgeClientExample internal lcBridgeClient;

    function setUp() public virtual {
        lancaCanonicalBridge = LancaCanonicalBridge(
            address(
                new TransparentUpgradeableProxy(
                    address(
                        new LancaCanonicalBridge(
                            SRC_CHAIN_SELECTOR,
                            s_conceroRouter,
                            address(s_usdcE),
                            s_lancaBridgeL1Mock
                        )
                    ),
                    s_proxyDeployer,
                    abi.encodeWithSelector(LancaCanonicalBridgeBase.initialize.selector, s_deployer)
                )
            )
        );

        _setValidatorLibs(address(lancaCanonicalBridge));
        _setRelayerLib(address(lancaCanonicalBridge));

        lcBridgeClient = new LancaCanonicalBridgeClientExample(
            address(lancaCanonicalBridge),
            address(s_usdcE)
        );

        MockUSDCe(address(s_usdcE)).setMinter(address(lancaCanonicalBridge));
        MockUSDCe(address(s_usdcE)).mintTo(s_user, AMOUNT);

        vm.deal(s_user, 1e18);

        vm.startPrank(s_deployer);
        lancaCanonicalBridge.setRateLimit(SRC_CHAIN_SELECTOR, MAX_RATE_AMOUNT, REFILL_SPEED, true);
        lancaCanonicalBridge.setRateLimit(SRC_CHAIN_SELECTOR, MAX_RATE_AMOUNT, REFILL_SPEED, false);
        vm.stopPrank();
    }

    function _approveBridge(uint256 amount) internal {
        vm.prank(s_user);
        s_usdcE.approve(address(lancaCanonicalBridge), amount);
    }

    function _getMessageFee() internal view returns (uint256) {
        return
            lancaCanonicalBridge.getBridgeNativeFee(
                ZERO_AMOUNT,
                DST_CHAIN_SELECTOR,
                MessageCodec.encodeEvmDstChainData(address(lancaCanonicalBridge), 0),
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
            BridgeCodec.encodeBridgeData(
                tokenSender,
                tokenAmount,
                MessageCodec.encodeEvmDstChainData(tokenReceiver, dstGasLimit),
                payload
            ),
            SRC_CHAIN_SELECTOR,
            address(lancaCanonicalBridge)
        );

        vm.prank(s_conceroRouter);
        lancaCanonicalBridge.conceroReceive(
            messageRequest.toMessageReceiptBytes(
                SRC_CHAIN_SELECTOR,
                s_lancaBridgeL1Mock,
                NONCE,
                new bytes[](0)
            ),
            s_validationChecks,
            s_validatorLibs,
            s_relayerLib
        );
    }
}
