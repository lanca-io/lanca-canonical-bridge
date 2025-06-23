// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IFiatTokenV1 is IERC20 {
    function mint(address to, uint256 amount) external returns (bool);
    function burn(uint256 amount) external;
}
