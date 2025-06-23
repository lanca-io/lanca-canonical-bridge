// SPDX-License-Identifier: MIT
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

library Namespaces {
    // bytes32 internal constant PARENT_POOL = getSafeStorageSlotByName("parentPool");

    function getSafeStorageSlotByName(string memory name) private pure returns (bytes32) {
        return
            keccak256(abi.encode(uint256(keccak256(abi.encodePacked(name))) - 1)) &
            ~bytes32(uint256(0xff));
    }
}

library Storage {
    struct Deposits {
        uint256 liquidityTokenAmountToDeposit;
    }

    struct ParentPool {
        mapping(bytes32 id => Deposits deposits) depositsById;
    }

    /* SLOT-BASED STORAGE ACCESS */
    function parentPool() internal pure returns (ParentPool storage s) {
        // bytes32 slot = Namespaces.PARENT_POOL;
        bytes32 slot = bytes32(uint256(1));
        assembly {
            s.slot := slot
        }
    }
}
