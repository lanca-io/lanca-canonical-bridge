// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts-v5/token/ERC20/ERC20.sol";

contract MockUSDCe is ERC20 {
    uint8 private _decimals;
    address private _minter;
    bool public shouldFailTransfer;
    bool public shouldFailMint;

    modifier onlyMinter() {
        require(msg.sender == _minter, "FiatToken: caller is not the masterMinter");
        _;
    }

    constructor(string memory name, string memory symbol, uint8 decimalsValue) ERC20(name, symbol) {
        _decimals = decimalsValue;
    }

    function setMinter(address minter) external {
        _minter = minter;
    }

    function mintTo(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function mint(address to, uint256 amount) external onlyMinter returns (bool) {
        if (shouldFailMint) {
            return false;
        }
        _mint(to, amount);
        return true;
    }

    function burn(uint256 amount) external onlyMinter {
        _burn(msg.sender, amount);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function setShouldFailTransfer(bool _shouldFail) external {
        shouldFailTransfer = _shouldFail;
    }

    function setShouldFailMint(bool _shouldFail) external {
        shouldFailMint = _shouldFail;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        if (shouldFailTransfer) {
            return false;
        }
        return super.transferFrom(from, to, amount);
    }
}
