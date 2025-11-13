// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {IConceroRouter} from "@concero/v2-contracts/contracts/interfaces/IConceroRouter.sol";
import {MessageCodec} from "@concero/v2-contracts/contracts/common/libraries/MessageCodec.sol";

import {LancaCanonicalBridgeL1} from "contracts/LancaCanonicalBridge/LancaCanonicalBridgeL1.sol";
import {LancaCanonicalBridgePool} from "contracts/LancaCanonicalBridgePool/LancaCanonicalBridgePool.sol";
import {LancaCanonicalBridgeClientExample} from "contracts/LancaCanonicalBridgeClient/LancaCanonicalBridgeClientExample.sol";

import {MockUSDC} from "../../mocks/MockUSDC.sol";
import {DeployLCBridgeL1} from "../../scripts/deploy/DeployLCBridgeL1.s.sol";
import {BaseTest} from "../../utils/BaseTest.sol";

abstract contract LCBridgeL1Test is BaseTest {
    LancaCanonicalBridgeL1 internal lancaCanonicalBridgeL1;
    LancaCanonicalBridgePool internal lancaCanonicalBridgePool;
    LancaCanonicalBridgeClientExample internal lcBridgeClient;

    function setUp() public virtual override {
        super.setUp();

        lancaCanonicalBridgeL1 = LancaCanonicalBridgeL1(
            (new DeployLCBridgeL1()).deploy(conceroRouter, usdc, deployer)
        );

        uint24[] memory dstChainSelectors = new uint24[](1);
        dstChainSelectors[0] = SRC_CHAIN_SELECTOR;

        address[] memory validatorLibs = new address[](1);
        validatorLibs[0] = validatorLib;
        bytes[] memory validatorConfigs = new bytes[](1);
        validatorConfigs[0] = new bytes(0);
        bool[] memory isAllowed = new bool[](1);
        isAllowed[0] = true;

        LancaCanonicalBridgeL1.ValidatorLibs[]
            memory validatorLibsStruct = new LancaCanonicalBridgeL1.ValidatorLibs[](1);
        validatorLibsStruct[0] = LancaCanonicalBridgeL1.ValidatorLibs({
            validatorLibs: validatorLibs,
            validatorConfigs: validatorConfigs,
            isAllowed: isAllowed,
            requiredValidatorsCount: 1
        });

        vm.startPrank(deployer);
        lancaCanonicalBridgeL1.setRelayerLib(SRC_CHAIN_SELECTOR, relayerLib, new bytes(1), true);
        lancaCanonicalBridgeL1.setValidatorLibs(dstChainSelectors, validatorLibsStruct);
        vm.stopPrank();

        lancaCanonicalBridgePool = new LancaCanonicalBridgePool(
            usdc,
            address(lancaCanonicalBridgeL1),
            DST_CHAIN_SELECTOR
        );

        lcBridgeClient = new LancaCanonicalBridgeClientExample(
            address(lancaCanonicalBridgeL1),
            usdc
        );

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
        return lancaCanonicalBridgeL1.getBridgeNativeFee(DST_CHAIN_SELECTOR, GAS_LIMIT);
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

    function _buildMessageRequest(
        address tokenSender,
        address tokenReceiver,
        uint256 tokenAmount,
        uint256 dstGasLimit,
        bytes memory dstCallData
    ) internal view returns (IConceroRouter.MessageRequest memory) {
        bytes memory payload = _encodeBridgeParams(
            tokenSender,
            tokenReceiver,
            tokenAmount,
            dstGasLimit,
            dstCallData
        );
        return _buildMessageRequest(payload, 300_000, type(uint64).max, address(0));
    }

    function _buildMessageRequest(
        bytes memory payload,
        uint32 dstChainGasLimit,
        uint64 srcBlockConfirmations,
        address feeToken
    ) internal view returns (IConceroRouter.MessageRequest memory) {
        address[] memory validatorLibs = new address[](1);
        validatorLibs[0] = validatorLib;

        return
            IConceroRouter.MessageRequest({
                dstChainSelector: SRC_CHAIN_SELECTOR,
                srcBlockConfirmations: srcBlockConfirmations,
                feeToken: feeToken,
                dstChainData: MessageCodec.encodeEvmDstChainData(
                    address(lancaCanonicalBridgeL1),
                    dstChainGasLimit
                ),
                validatorLibs: validatorLibs,
                relayerLib: relayerLib,
                validatorConfigs: new bytes[](1),
                relayerConfig: new bytes(1),
                payload: payload
            });
    }
}
