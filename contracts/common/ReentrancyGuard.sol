// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {Storage as s} from "../LancaCanonicalBridge/libraries/Storage.sol";

abstract contract ReentrancyGuard {
    using s for s.NonReentrant;

    uint256 internal constant NOT_ENTERED = 1;
    uint256 internal constant ENTERED = 2;

    error ReentrantCall();

    modifier nonReentrant() {
        require(s.nonReentrant().status != ENTERED, ReentrantCall());

        s.nonReentrant().status = ENTERED;
        _;
        s.nonReentrant().status = NOT_ENTERED;
    }
}
