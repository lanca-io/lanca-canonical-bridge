// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

contract PauseDummy {
    fallback() external {
        revert("paused");
    }
    receive() external payable {
        revert("paused");
    }
}
