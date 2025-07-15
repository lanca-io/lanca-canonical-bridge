// SPDX-License-Identifier: MIT
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {FlowLimiter} from "../FlowLimiter.sol";

library Namespaces {
    bytes32 internal constant L1_BRIDGE =
        keccak256(
            abi.encode(uint256(keccak256(abi.encodePacked("lancabridge.l1bridge.storage"))) - 1)
        ) & ~bytes32(uint256(0xff));

    bytes32 internal constant NON_REENTRANT =
        keccak256(
            abi.encode(uint256(keccak256(abi.encodePacked("lancabridge.nonreentrant.storage"))) - 1)
        ) & ~bytes32(uint256(0xff));

    bytes32 internal constant FLOW_LIMITS =
        keccak256(
            abi.encode(uint256(keccak256(abi.encodePacked("lancabridge.flowlimits.storage"))) - 1)
        ) & ~bytes32(uint256(0xff));
}

library Storage {
    struct L1Bridge {
        uint256[50] __var_gap;
        uint256[50] __array_gap;
        mapping(uint24 dstChainSelector => address pool) pools;
        mapping(uint24 dstChainSelector => address dstBridge) dstBridges;
    }

    struct FlowLimits {
        uint256[50] __var_gap;
        uint256[50] __array_gap;
        mapping(uint24 dstChainSelector => FlowLimiter.FlowLimit) outboundFlows;
        mapping(uint24 dstChainSelector => FlowLimiter.FlowLimit) inboundFlows;
    }

    struct NonReentrant {
        uint256 status;
    }

    /* SLOT-BASED STORAGE ACCESS */
    function l1Bridge() internal pure returns (L1Bridge storage s) {
        bytes32 slot = Namespaces.L1_BRIDGE;
        assembly {
            s.slot := slot
        }
    }

    function nonReentrant() internal pure returns (NonReentrant storage s) {
        bytes32 slot = Namespaces.NON_REENTRANT;
        assembly {
            s.slot := slot
        }
    }

    function flowLimits() internal pure returns (FlowLimits storage s) {
        bytes32 slot = Namespaces.FLOW_LIMITS;
        assembly {
            s.slot := slot
        }
    }
}
