// SPDX-License-Identifier: MIT
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {RateLimiter} from "contracts/common/RateLimiter.sol";

library Namespaces {
    bytes32 internal constant L1_BRIDGE =
        keccak256(
            abi.encode(uint256(keccak256(abi.encodePacked("lancabridge.l1bridge.storage"))) - 1)
        ) & ~bytes32(uint256(0xff));

    bytes32 internal constant NON_REENTRANT =
        keccak256(
            abi.encode(uint256(keccak256(abi.encodePacked("lancabridge.nonreentrant.storage"))) - 1)
        ) & ~bytes32(uint256(0xff));

    bytes32 internal constant RATE_LIMITS =
        keccak256(
            abi.encode(uint256(keccak256(abi.encodePacked("lancabridge.ratelimits.storage"))) - 1)
        ) & ~bytes32(uint256(0xff));
}

library Storage {
    struct L1Bridge {
        uint256[50] __var_gap;
        uint256[50] __array_gap;
        mapping(uint24 dstChainSelector => address pool) pools;
        mapping(uint24 dstChainSelector => address lane) lanes;
    }

    struct RateLimits {
        uint256[50] __var_gap;
        uint256[50] __array_gap;
        mapping(uint24 dstChainSelector => RateLimiter.Config config) outboundRateLimit;
        mapping(uint24 dstChainSelector => RateLimiter.Config config) inboundRateLimit;
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

    function rateLimits() internal pure returns (RateLimits storage s) {
        bytes32 slot = Namespaces.RATE_LIMITS;
        assembly {
            s.slot := slot
        }
    }
}
