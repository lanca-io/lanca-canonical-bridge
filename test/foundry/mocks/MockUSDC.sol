// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    uint8 private _decimals;
    bool public shouldFailTransfer = false;

    constructor(string memory name, string memory symbol, uint8 decimalsValue) ERC20(name, symbol) {
        _decimals = decimalsValue;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function setShouldFailTransfer(bool _shouldFail) external {
        shouldFailTransfer = _shouldFail;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        if (shouldFailTransfer) {
            return false;
        }
        return super.transferFrom(from, to, amount);
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        if (shouldFailTransfer) {
            return false;
        }
        return super.transfer(to, amount);
    }
}