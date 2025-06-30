// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {Script} from "forge-std/src/Script.sol";

import {ConceroTypes} from "@concero/messaging-contracts-v2/contracts/ConceroClient/ConceroTypes.sol";
import {IConceroRouter} from "@concero/messaging-contracts-v2/contracts/interfaces/IConceroRouter.sol";

contract MockConceroRouter is IConceroRouter {
    function conceroSend(
        uint24 dstChainSelector,
        bool shouldFinaliseSrc,
        address feeToken,
        ConceroTypes.EvmDstChainData memory dstChainData,
        bytes calldata message
    ) external payable returns (bytes32 messageId) {}

    function getMessageFee(
        uint24 dstChainSelector,
        bool shouldFinaliseSrc,
        address feeToken,
        ConceroTypes.EvmDstChainData memory dstChainData
    ) external view returns (uint256) {}
}

contract DeployMockConceroRouter is Script {
    function deployConceroRouter() public returns (MockConceroRouter) {
        MockConceroRouter conceroRouter = new MockConceroRouter();

        return conceroRouter;
    }
}
