// SPDX-License-Identifier: MIT
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

library Namespaces {
    bytes32 internal constant BRIDGE =
        keccak256(
            abi.encode(uint256(keccak256(abi.encodePacked("lancabridge.bridge.storage"))) - 1)
        ) & ~bytes32(uint256(0xff));

    bytes32 internal constant L1_BRIDGE =
        keccak256(
            abi.encode(uint256(keccak256(abi.encodePacked("lancabridge.l1bridge.storage"))) - 1)
        ) & ~bytes32(uint256(0xff));
}

library Storage {
    struct L1Bridge {
        uint256[50] __var_gap;
        uint256[50] __array_gap;
        mapping(uint24 dstChainSelector => address pool) pools;
    }

    struct Bridge {
        uint256[50] __var_gap;
        uint256[50] __array_gap;
        mapping(uint24 dstChainSelector => address lane) lanes;
    }

    function bridge() internal pure returns (Bridge storage s) {
        bytes32 slot = Namespaces.BRIDGE;
        assembly {
            s.slot := slot
        }
    }

    /* SLOT-BASED STORAGE ACCESS */
    function l1Bridge() internal pure returns (L1Bridge storage s) {
        bytes32 slot = Namespaces.L1_BRIDGE;
        assembly {
            s.slot := slot
        }
    }
}
